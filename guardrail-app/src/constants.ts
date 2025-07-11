// Configuration constants for the Guardrail app
export const GUARDRAIL_ADDRESS = '0xe809d81ac67b3629a5dab4e0293f64537353f40d' as const // Sepolia

// Storage slots for Safe contract
export const GUARD_STORAGE_SLOT = '0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8' as const
export const MODULE_GUARD_STORAGE_SLOT = '0xb104e0b93118902c651344349b610029d694cfdec91c589c91ebafbcd0289947' as const

// Contract ABI interface
export const CONTRACT_INTERFACE_ABI = [
  'function setGuard(address guard)',
  // "function setModuleGuard(address moduleGuard)",
  'function getStorageAt(uint256 offset, uint256 length) public view returns (bytes memory)',
  'function removalSchedule(address safe) public view returns (uint256)',
  'function scheduleGuardRemoval() public',
  'function delegateAllowance(address to, bool oneTimeAllowance, bool reset) public',
  'function immediateDelegateAllowance(address to, bool oneTime) public',
  'function getDelegates(address account) external view returns (address[] memory)',
  'function delegatedAllowance(address safe, address delegate) external view returns (tuple(bool oneTimeAllowance, uint256 allowedTimestamp) memory)',
] as const

// Time constants
export const MILLISECONDS_IN_SECOND = 1000n
