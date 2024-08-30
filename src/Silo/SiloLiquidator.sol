// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IFlashLiquidationReceiver.sol";
import "./interfaces/ISilo.sol";
import "./interfaces/IPriceProvider.sol";
import "./interfaces/ISwapper.sol";
import "./interfaces/ISiloRepository.sol";
import "./interfaces/IPriceProvidersRepository.sol";

import "./lib/Ping.sol";
import "./lib/Solvency.sol";

interface IWrappedNativeToken is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

contract SiloLiquidator is IFlashLiquidationReceiver, Ownable {
    bytes4 private constant _SWAP_AMOUNT_IN_SELECTOR =
        bytes4(keccak256("swapAmountIn(address,address,uint256,address)"));

    bytes4 private constant _SWAP_AMOUNT_OUT_SELECTOR =
        bytes4(keccak256("swapAmountOut(address,address,uint256,address)"));

    ISiloRepository public immutable siloRepository;
    IERC20 public immutable quoteToken;

    mapping(IPriceProvider => ISwapper) public swappers;

    IPriceProvider[] public priceProvidersWithSwapOption;

    event LiquidationBalance(address user, uint256 quoteAmountFromCollaterals);

    constructor(
        address _repository,
        IPriceProvider[] memory _priceProvidersWithSwapOption,
        ISwapper[] memory _swappers
    ) Ownable(msg.sender) {
        require(
            Ping.pong(ISiloRepository(_repository).siloRepositoryPing),
            "invalid _repository"
        );

        require(
            _swappers.length == _priceProvidersWithSwapOption.length,
            "swappers != providers"
        );

        siloRepository = ISiloRepository(_repository);

        for (uint256 i = 0; i < _swappers.length; i++) {
            swappers[_priceProvidersWithSwapOption[i]] = _swappers[i];
        }

        priceProvidersWithSwapOption = _priceProvidersWithSwapOption;

        IPriceProvidersRepository priceProviderRepo =
            ISiloRepository(_repository).priceProvidersRepository();
        quoteToken = IERC20(priceProviderRepo.quoteToken());
    }

    receive() external payable {}

    function withdraw() external onlyOwner {
        uint256 amount = quoteToken.balanceOf(address(this));
        if (amount == 0) return;

        quoteToken.transfer(msg.sender, amount);
    }

    function withdrawEth() external onlyOwner {
        uint256 amount = quoteToken.balanceOf(address(this));
        if (amount == 0) return;

        IWrappedNativeToken(address(quoteToken)).withdraw(amount);
        (bool sent,) = (msg.sender).call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    function executeLiquidation(address[] calldata _users, ISilo _silo) external {
        uint256 gasStart = 29_001_691;
        _silo.flashLiquidate(_users, abi.encode(gasStart));
    }

    function setSwapper(IPriceProvider _oracle, ISwapper _swapper) external onlyOwner {
        swappers[_oracle] = _swapper;
    }

    function siloLiquidationCallback(
        address _user,
        address[] calldata _assets,
        uint256[] calldata _receivedCollaterals,
        uint256[] calldata _shareAmountsToRepaid,
        bytes memory _flashReceiverData
    ) external override {
        ISilo silo = ISilo(msg.sender);
        require(siloRepository.isSilo(address(silo)), "not a Silo");

        uint256 quoteAmountFromCollaterals;

        // swap all for quote token
        unchecked {
            for (uint256 i = 0; i < _assets.length; i++) {
                quoteAmountFromCollaterals +=
                    _swapForQuote(_assets[i], _receivedCollaterals[i]);
            }
        }

        uint256 quoteSpendOnRepay;

        // repay
        for (uint256 i = 0; i < _assets.length; i++) {
            if (_shareAmountsToRepaid[i] == 0) continue;

            unchecked {
                quoteSpendOnRepay += _swapForAsset(_assets[i], _shareAmountsToRepaid[i]);
            }

            IERC20(_assets[i]).approve(address(silo), _shareAmountsToRepaid[i]);
            silo.repayFor(_assets[i], _user, _shareAmountsToRepaid[i]);

            // DEFLATIONARY TOKENS ARE NOT SUPPORTED
            // we are not using lower limits for swaps so we may not get enough tokens to do full repay
            // our assumption here is that `_shareAmountsToRepaid[i]` is total amount to repay the full debt
            // if after repay user has no debt in this asset, the swap is acceptable
            require(
                silo.assetStorage(_assets[i]).debtToken.balanceOf(_user) == 0,
                "repay failed"
            );
        }

        emit LiquidationBalance(_user, quoteAmountFromCollaterals);
    }

    function priceProvidersWithSwapOptionCount() external view returns (uint256) {
        return priceProvidersWithSwapOption.length;
    }

    function checkSolvency(address[] memory _users, ISilo[] memory _silos)
        external
        view
        returns (bool[] memory)
    {
        require(_users.length == _silos.length, "oops");

        bool[] memory solvency = new bool[](_users.length);

        for (uint256 i; i < _users.length; i++) {
            solvency[i] = _silos[i].isSolvent(_users[i]);
        }

        return solvency;
    }

    function checkDebt(address[] memory _users, ISilo[] memory _silos)
        external
        view
        returns (bool[] memory)
    {
        bool[] memory hasDebt = new bool[](_users.length);

        for (uint256 i; i < _users.length; i++) {
            hasDebt[i] = inDebt(_silos[i], _users[i]);
        }

        return hasDebt;
    }

    function getUserLiquidationThreshold(address _silo, address _user)
        external
        view
        returns (uint256 liquidationThreshold)
    {
        (address[] memory assets, ISilo.AssetStorage[] memory assetsStates) =
            ISilo(_silo).getAssetsWithState();

        liquidationThreshold = Solvency.calculateLTVLimit(
            Solvency.SolvencyParams(siloRepository, ISilo(_silo), assets, assetsStates, _user),
            Solvency.TypeofLTV.LiquidationThreshold
        );
    }

    function findPriceProvider(address _asset) public view returns (IPriceProvider) {
        IPriceProvider[] memory providers = priceProvidersWithSwapOption;

        for (uint256 i = 0; i < providers.length; i++) {
            IPriceProvider provider = providers[i];
            if (provider.assetSupported(_asset)) return provider;
        }

        revert("provider not found");
    }

    /// @notice Check if user is in debt
    /// @param _silo Silo address from which to read data
    /// @param _user wallet address for which to read data
    /// @return TRUE if user borrowed any amount of any asset, otherwise FALSE
    function inDebt(ISilo _silo, address _user) public view returns (bool) {
        address[] memory allAssets = _silo.getAssets();

        for (uint256 i; i < allAssets.length; i++) {
            if (_silo.assetStorage(allAssets[i]).debtToken.balanceOf(_user) != 0) {
                return true;
            }
        }

        return false;
    }

    function _swapForQuote(address _asset, uint256 _amount) internal returns (uint256) {
        if (_amount == 0 || _asset == address(quoteToken)) return _amount;

        IPriceProvider priceProvider = findPriceProvider(_asset);
        ISwapper swapper = swappers[priceProvider];

        bytes memory callData = abi.encodeWithSelector(
            _SWAP_AMOUNT_IN_SELECTOR, _asset, quoteToken, _amount, _asset
        );

        // no need for safe approval, because we always using 100%
        IERC20(_asset).approve(swapper.spenderToApprove(), _amount);
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = address(swapper).delegatecall(callData);
        require(success, "swapAmountIn failed");

        return abi.decode(data, (uint256));
    }

    /// @dev it swaps quote token for asset
    /// @param _asset address
    /// @param _amount exact amount OUT, what we want to receive
    /// @return amount of quote token used for swap
    function _swapForAsset(address _asset, uint256 _amount) internal returns (uint256) {
        if (_amount == 0 || address(quoteToken) == _asset) return _amount;

        IPriceProvider priceProvider = findPriceProvider(_asset);
        ISwapper swapper = swappers[priceProvider];

        bytes memory callData = abi.encodeWithSelector(
            _SWAP_AMOUNT_OUT_SELECTOR, quoteToken, _asset, _amount, _asset
        );

        address spender = swapper.spenderToApprove();
        IERC20(quoteToken).approve(spender, type(uint256).max);

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = address(swapper).delegatecall(callData);
        require(success, "swapAmountOut failed");
        IERC20(quoteToken).approve(spender, 0);

        return abi.decode(data, (uint256));
    }
}
