import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IStream {
    function locked() external view returns (uint256);
    function token() external view returns (address);
}

contract LockedChampCalculator is Ownable{
    // Add the library methods
    using EnumerableSet for EnumerableSet.AddressSet;

    IERC20 immutable token;
    // Declare a set state variable
    EnumerableSet.AddressSet private streams;
    EnumerableSet.AddressSet private treasuries;

    constructor(address _token) Ownable(msg.sender) { 
        token = IERC20(_token);
    }

    function updateStreams(address[] memory _addresses, bool _add) external onlyOwner {
        for(uint256 i = 0; i < _addresses.length; i++) {
            if(_add) {
                address _stream = _addresses[i];
                require(IStream(_stream).token() == address(token));
                streams.add(_stream);
            } else {
                streams.remove(_addresses[i]);
            }
        }
    }

    function updateTreasuries(address[] memory _addresses, bool _add) external onlyOwner {
        for(uint256 i = 0; i < _addresses.length; i++) {
            if(_add) {
                treasuries.add(_addresses[i]);
            } else {
                treasuries.remove(_addresses[i]);
            }
        }
    }

    function lockedTokens() external view returns (uint256 locked_) {
        uint256 sl = streams.length();
        uint256 tl = treasuries.length();

        if(sl > 0) {
            for(uint256 i = 0; i < sl; i++) {
                locked_ += IStream(streams.at(i)).locked();
            }
        }

        if(tl > 0) {
            for(uint256 i = 0; i < tl; i++) {
                locked_ += token.balanceOf(treasuries.at(i));
            }
        }
    }
}