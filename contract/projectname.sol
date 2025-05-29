
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Carbon Credit Marketplace with IoT Integration
 * @dev A decentralized marketplace for trading carbon credits verified through IoT data
 * @author Your Name
 */
contract Project {
    
    // Struct to represent a carbon credit
    struct CarbonCredit {
        uint256 creditId;
        address producer;
        uint256 co2Reduced; // Amount of CO2 reduced in kilograms
        uint256 timestamp;
        string deviceId; // IoT device identifier
        bool isVerified;
        uint256 price; // Price in wei
        bool isForSale;
        address currentOwner;
    }
    
    // Struct for IoT device registration
    struct IoTDevice {
        string deviceId;
        address owner;
        string deviceType; // "solar", "wind", "ev_charger", "biomass", etc.
        bool isActive;
        uint256 totalCreditsGenerated;
        uint256 registrationTime;
    }
    
    // State variables
    uint256 private creditCounter;
    mapping(uint256 => CarbonCredit) public carbonCredits;
    mapping(string => IoTDevice) public iotDevices;
    mapping(address => bool) public authorizedOracles;
    mapping(address => uint256[]) public userCredits;
    mapping(address => uint256) public userTotalCO2Reduced;
    
    // Events
    event DeviceRegistered(string indexed deviceId, address indexed owner, string deviceType);
    event CreditGenerated(uint256 indexed creditId, address indexed producer, uint256 co2Reduced, string deviceId);
    event CreditVerified(uint256 indexed creditId, address indexed oracle);
    event CreditTraded(uint256 indexed creditId, address indexed seller, address indexed buyer, uint256 price);
    event CreditListed(uint256 indexed creditId, uint256 price);
    event OracleAuthorized(address indexed oracle);
    
    // Modifiers
    modifier onlyDeviceOwner(string memory deviceId) {
        require(iotDevices[deviceId].owner == msg.sender, "Not device owner");
        _;
    }
    
    modifier onlyAuthorizedOracle() {
        require(authorizedOracles[msg.sender], "Not authorized oracle");
        _;
    }
    
    modifier validCredit(uint256 creditId) {
        require(creditId < creditCounter, "Credit does not exist");
        _;
    }
    
    constructor() {
        creditCounter = 0;
        // Contract deployer becomes the first authorized oracle
        authorizedOracles[msg.sender] = true;
    }
    
    /**
     * @dev Core Function 1: Register IoT Device
     * Allows users to register their environmental IoT devices
     * @param deviceId Unique identifier for the IoT device
     * @param deviceType Type of environmental device
     */
    function registerDevice(string memory deviceId, string memory deviceType) external {
        require(bytes(deviceId).length > 0, "Device ID cannot be empty");
        require(bytes(deviceType).length > 0, "Device type cannot be empty");
        require(iotDevices[deviceId].owner == address(0), "Device already registered");
        
        iotDevices[deviceId] = IoTDevice({
            deviceId: deviceId,
            owner: msg.sender,
            deviceType: deviceType,
            isActive: true,
            totalCreditsGenerated: 0,
            registrationTime: block.timestamp
        });
        
        emit DeviceRegistered(deviceId, msg.sender, deviceType);
    }
    
    /**
     * @dev Core Function 2: Generate Carbon Credit
     * Creates carbon credits based on IoT device environmental data
     * @param deviceId IoT device that generated the environmental impact
     * @param co2Reduced Amount of CO2 reduced in kilograms
     */
    function generateCarbonCredit(string memory deviceId, uint256 co2Reduced) 
        external 
        onlyDeviceOwner(deviceId) 
    {
        require(iotDevices[deviceId].isActive, "Device is not active");
        require(co2Reduced > 0, "CO2 reduction must be positive");
        
        uint256 creditId = creditCounter;
        
        carbonCredits[creditId] = CarbonCredit({
            creditId: creditId,
            producer: msg.sender,
            co2Reduced: co2Reduced,
            timestamp: block.timestamp,
            deviceId: deviceId,
            isVerified: false,
            price: 0,
            isForSale: false,
            currentOwner: msg.sender
        });
        
        // Update device statistics
        iotDevices[deviceId].totalCreditsGenerated++;
        
        // Update user statistics
        userCredits[msg.sender].push(creditId);
        userTotalCO2Reduced[msg.sender] += co2Reduced;
        
        creditCounter++;
        
        emit CreditGenerated(creditId, msg.sender, co2Reduced, deviceId);
    }
    
    /**
     * @dev Core Function 3: Trade Carbon Credits
     * Enables peer-to-peer trading of verified carbon credits
     * @param creditId ID of the carbon credit to purchase
     */
    function purchaseCarbonCredit(uint256 creditId) 
        external 
        payable 
        validCredit(creditId) 
    {
        CarbonCredit storage credit = carbonCredits[creditId];
        
        require(credit.isVerified, "Credit not verified by oracle");
        require(credit.isForSale, "Credit not for sale");
        require(credit.currentOwner != msg.sender, "Cannot buy your own credit");
        require(msg.value >= credit.price, "Insufficient payment");
        
        address seller = credit.currentOwner;
        uint256 salePrice = credit.price;
        
        // Update credit ownership
        credit.currentOwner = msg.sender;
        credit.isForSale = false;
        credit.price = 0;
        
        // Update user credit arrays
        _removeFromUserCredits(seller, creditId);
        userCredits[msg.sender].push(creditId);
        
        // Transfer payment to seller
        payable(seller).transfer(salePrice);
        
        // Refund excess payment
        if (msg.value > salePrice) {
            payable(msg.sender).transfer(msg.value - salePrice);
        }
        
        emit CreditTraded(creditId, seller, msg.sender, salePrice);
    }
    
    /**
     * @dev Verify carbon credit (Oracle function)
     * @param creditId ID of the carbon credit to verify
     */
    function verifyCarbonCredit(uint256 creditId) 
        external 
        onlyAuthorizedOracle 
        validCredit(creditId) 
    {
        require(!carbonCredits[creditId].isVerified, "Credit already verified");
        
        carbonCredits[creditId].isVerified = true;
        emit CreditVerified(creditId, msg.sender);
    }
    
    /**
     * @dev List carbon credit for sale
     * @param creditId ID of the carbon credit
     * @param price Price in wei
     */
    function listCreditForSale(uint256 creditId, uint256 price) 
        external 
        validCredit(creditId) 
    {
        require(carbonCredits[creditId].currentOwner == msg.sender, "Not credit owner");
        require(carbonCredits[creditId].isVerified, "Credit not verified");
        require(price > 0, "Price must be positive");
        
        carbonCredits[creditId].price = price;
        carbonCredits[creditId].isForSale = true;
        
        emit CreditListed(creditId, price);
    }
    
    /**
     * @dev Authorize new oracle
     * @param oracle Address of the new oracle
     */
    function authorizeOracle(address oracle) external {
        require(authorizedOracles[msg.sender], "Only authorized oracle can add new oracles");
        require(oracle != address(0), "Invalid oracle address");
        
        authorizedOracles[oracle] = true;
        emit OracleAuthorized(oracle);
    }
    
    /**
     * @dev Get user's carbon credits
     * @param user Address of the user
     * @return Array of credit IDs owned by the user
     */
    function getUserCredits(address user) external view returns (uint256[] memory) {
        return userCredits[user];
    }
    
    /**
     * @dev Get all credits available for sale
     * @return creditIds Array of credit IDs for sale
     * @return prices Array of corresponding prices
     */
    function getCreditsForSale() external view returns (uint256[] memory creditIds, uint256[] memory prices) {
        uint256 forSaleCount = 0;
        
        // Count credits for sale
        for (uint256 i = 0; i < creditCounter; i++) {
            if (carbonCredits[i].isForSale && carbonCredits[i].isVerified) {
                forSaleCount++;
            }
        }
        
        creditIds = new uint256[](forSaleCount);
        prices = new uint256[](forSaleCount);
        
        uint256 index = 0;
        for (uint256 i = 0; i < creditCounter; i++) {
            if (carbonCredits[i].isForSale && carbonCredits[i].isVerified) {
                creditIds[index] = i;
                prices[index] = carbonCredits[i].price;
                index++;
            }
        }
        
        return (creditIds, prices);
    }
    
    /**
     * @dev Get device information
     * @param deviceId Device identifier
     * @return Device information struct
     */
    function getDeviceInfo(string memory deviceId) external view returns (IoTDevice memory) {
        return iotDevices[deviceId];
    }
    
    /**
     * @dev Get total credits generated
     * @return Total number of credits in the system
     */
    function getTotalCredits() external view returns (uint256) {
        return creditCounter;
    }
    
    /**
     * @dev Internal function to remove credit from user's array
     * @param user User address
     * @param creditId Credit ID to remove
     */
    function _removeFromUserCredits(address user, uint256 creditId) internal {
        uint256[] storage credits = userCredits[user];
        for (uint256 i = 0; i < credits.length; i++) {
            if (credits[i] == creditId) {
                credits[i] = credits[credits.length - 1];
                credits.pop();
                break;
            }
        }
    }
    
    /**
     * @dev Emergency function to deactivate a device
     * @param deviceId Device to deactivate
     */
    function deactivateDevice(string memory deviceId) external onlyDeviceOwner(deviceId) {
        iotDevices[deviceId].isActive = false;
    }
    
    /**
     * @dev Reactivate a device
     * @param deviceId Device to reactivate
     */
    function reactivateDevice(string memory deviceId) external onlyDeviceOwner(deviceId) {
        iotDevices[deviceId].isActive = true;
    }
}
