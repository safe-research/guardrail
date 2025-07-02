import { useCallback, useEffect, useState } from 'react'
import './App.css'
import type { BaseTransaction } from '@safe-global/safe-apps-sdk'
import { useSafeAppsSDK } from '@safe-global/safe-apps-react-sdk'
import SafeAppsSDK from '@safe-global/safe-apps-sdk'
import { ethers } from 'ethers';
import Button from '@mui/material/Button';
import { Alert, Checkbox, FormControlLabel, FormGroup, Paper, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, TextField } from '@mui/material'

const GUARDRAIL_ADDRESS = ethers.getAddress(`0xe809d81ac67b3629a5dab4e0293f64537353f40d`) // Sepolia address of the App Guardrail contract
const GUARD_STORAGE_SLOT = `0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8` // Storage slot for the Tx Guard in the Safe contract
// const MODULE_GUARD_STORAGE_SLOT = `0xb104e0b93118902c651344349b610029d694cfdec91c589c91ebafbcd0289947` // Storage slot for the Module Guard in the Safe contract

const CONTRACT_INTERFACE = new ethers.Interface([
  "function setGuard(address guard)",
  // "function setModuleGuard(address moduleGuard)",
  "function getStorageAt(uint256 offset, uint256 length) public view returns (bytes memory)",
  "function removalSchedule(address safe) public view returns (uint256)",
  "function scheduleGuardRemoval() public",
  "function delegateAllowance(address to, bool oneTimeAllowance, bool reset) public",
  "function immediateDelegateAllowance(address to, bool oneTime) public",
  "function getDelegates(address account) external view returns (address[] memory)",
  "function delegatedAllowance(address safe, address delegate) external view returns (tuple(bool oneTimeAllowance, uint256 allowedTimestamp) memory)"
])

interface ImmediateDelegateAllowanceFormData {
  delegateAddress: string;
  allowOnce: boolean;
}

interface ScheduleDelegateAllowanceFormData extends ImmediateDelegateAllowanceFormData {
  reset: boolean;
}

const call = async (sdk: SafeAppsSDK, address: string, method: string, params: any[]): Promise<any> => {
  const resp = await sdk.eth.call([{
    to: address,
    data: CONTRACT_INTERFACE.encodeFunctionData(method, params)
  }])
  return CONTRACT_INTERFACE.decodeFunctionResult(method, resp)[0];
}

function App() {
  const [loading, setLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [txGuard, setTxGuard] = useState<string | null>(null)
  // const [moduleGuard, setModuleGuard] = useState<string | null>(null)
  const [guardRailInSafe, setGuardRailInSafe] = useState<boolean | null>(null)
  const [removalTimestamp, setRemovalTimestamp] = useState<bigint>(0n)
  const [delegatesInfo, setDelegatesInfo] = useState<{ delegate: string; allowedTimestamp: bigint; oneTime: boolean }[]>([])
  const useSafeSdk = useSafeAppsSDK()
  const { safe, sdk } = useSafeSdk

  const safeConnected = () => {
    setLoading(true)
    setErrorMessage(null)
    if (!safe) {
      setErrorMessage('No Safe connected')
      setLoading(false)
      return
    }
    setLoading(false)
  }

  const fetchTxGuardInfo = async () => {
    setLoading(true)
    setErrorMessage(null)
    try {
      // Get the Tx Guard
      const result = ethers.getAddress("0x" + (await call(sdk, safe.safeAddress, "getStorageAt", [GUARD_STORAGE_SLOT, 1])).slice(26))
      setTxGuard(result)
    } catch (error) {
      setErrorMessage('Failed to fetch transaction guard with error: ' + error)
    } finally {
      setLoading(false)
    }
  }

  // const fetchModuleGuardInfo = async () => {
  //   setLoading(true)
  //   setErrorMessage(null)
  //   try {
  //     // Get the Module Guard
  //     const result = ethers.getAddress("0x" + (await call(sdk, safe.safeAddress, "getStorageAt", [MODULE_GUARD_STORAGE_SLOT, 1])).slice(26))
  //     setModuleGuard(result)
  //   } catch (error) {
  //     setErrorMessage('Failed to fetch module guard with error: ' + error)
  //   } finally {
  //     setLoading(false)
  //   }
  // } 

  const fetchGuardRemovalInfo = async () => {
    setLoading(true)
    setErrorMessage(null)
    try {
      // Check if the Tx Guard removal is already set
      const result = await call(sdk, GUARDRAIL_ADDRESS, "removalSchedule", [ethers.getAddress(safe.safeAddress)])
      if (result > 0n) {
        setRemovalTimestamp(result * 1000n) // Convert to milliseconds
      }
    } catch (error) {
      setErrorMessage('Failed to fetch guard removal info with error: ' + error)
    } finally {
      setLoading(false)
    }
  }

  const fetchDelegateInfo = async (delegate: string) => {
    setLoading(true)
    setErrorMessage(null)
    try {
      // Fetch the delegate allowance info
      const result = await call(sdk, GUARDRAIL_ADDRESS, "delegatedAllowance", [ethers.getAddress(safe.safeAddress), ethers.getAddress(delegate)])
      console.log(`Delegate: ${delegate}, Allowed Timestamp: ${result.allowedTimestamp}, One Time: ${result.oneTimeAllowance}`)
      return {
        delegate,
        allowedTimestamp: result.allowedTimestamp * 1000n, // Convert to milliseconds
        oneTime: result.oneTimeAllowance
      }
    } catch (error) {
      setErrorMessage('Failed to fetch delegate info for ' + delegate + ' with error: ' + error)
    } finally {
      setLoading(false)
    }
  }

  const fetchCurrentDelegates = async () => {
    setLoading(true)
    setErrorMessage(null)

    try {
      // Fetch current delegates
      const result = await call(sdk, GUARDRAIL_ADDRESS, "getDelegates", [ethers.getAddress(safe.safeAddress)])
      
      // Convert proxy to array and then process addresses
      const delegatesArray = Array.from(result)
      let processedDelegates: string[] = []
      if (Array.isArray(delegatesArray)) {
        processedDelegates = delegatesArray.map((addr) => ethers.getAddress(addr as string))
      } else {
        setErrorMessage('Unexpected response format for delegates')
      }
      // Fetch delegate info for each delegate
      const delegateInfoPromises = processedDelegates.map((delegate) => fetchDelegateInfo(delegate))
      const delegateInfos = await Promise.all(delegateInfoPromises)
      // Filter out any null results (in case of errors)
      const validDelegateInfos = delegateInfos.filter((info) => info !== null) as { delegate: string; allowedTimestamp: bigint; oneTime: boolean }[]
      setDelegatesInfo(validDelegateInfos)
    } catch (error) {
      setErrorMessage('Failed to fetch current delegates with error: ' + error)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    safeConnected()
    if (safe && safe.safeAddress) {
      fetchTxGuardInfo()
      // fetchModuleGuardInfo()
      fetchGuardRemovalInfo()
      fetchCurrentDelegates()
    }
  }, [safe, sdk])

  useEffect(() => {
      if (txGuard == GUARDRAIL_ADDRESS /* && moduleGuard == GUARDRAIL_ADDRESS*/) {
        setGuardRailInSafe(true)
      }
    }, [txGuard, /*moduleGuard*/])  

  const activateGuardrail = useCallback(async (activate: boolean) => {
    setLoading(true)
    setErrorMessage(null)
    const guardAddress = activate ? GUARDRAIL_ADDRESS : ethers.ZeroAddress;
    try {
      const txs: BaseTransaction[] = [
        {
          to: safe.safeAddress,
          value: "0",
          data: CONTRACT_INTERFACE.encodeFunctionData("setGuard", [guardAddress])
        },
        // {
        //   to: safe.safeAddress,
        //   value: "0",
        //   data: CONTRACT_INTERFACE.encodeFunctionData("setModuleGuard", [guardAddress])
        // }
      ]
      await sdk.txs.send({
        txs
      })
    } catch (error) {
      setErrorMessage('Failed to submit transaction: ' + error)
    } finally {
      setLoading(false)
    }
  }, [safe, sdk])

  const scheduleGuardrailRemoval = useCallback(async () => {
    setLoading(true)
    setErrorMessage(null)
    try {
      const txs: BaseTransaction[] = [
        {
          to: GUARDRAIL_ADDRESS,
          value: "0",
          data: CONTRACT_INTERFACE.encodeFunctionData("scheduleGuardRemoval")
        }
      ]
      await sdk.txs.send({
        txs
      })
      fetchGuardRemovalInfo() // Refresh the removal timestamp after scheduling
    } catch (error) {
      setErrorMessage('Failed to schedule guardrail removal: ' + error)
    } finally {
      setLoading(false)
    }
  }, [safe, sdk]);

  const scheduleDelegateAllowance = useCallback(async (formData: ScheduleDelegateAllowanceFormData) => {
    setLoading(true)
    setErrorMessage(null)
    try {
      const txs: BaseTransaction[] = [
        {
          to: GUARDRAIL_ADDRESS,
          value: "0",
          data: CONTRACT_INTERFACE.encodeFunctionData("delegateAllowance", [
            ethers.getAddress(formData.delegateAddress),
            formData.allowOnce,
            formData.reset
          ])
        }
      ]
      await sdk.txs.send({
        txs
      })
    } catch (error) {
      setErrorMessage('Failed to schedule delegate allowance: ' + error)
    } finally {
      setLoading(false)
    }
  }, [safe, sdk]);

  const immediateDelegateAllowance = useCallback(async (formData: ImmediateDelegateAllowanceFormData) => {
    setLoading(true)
    setErrorMessage(null)
    try {
      const txs: BaseTransaction[] = [
        {
          to: GUARDRAIL_ADDRESS,
          value: "0",
          data: CONTRACT_INTERFACE.encodeFunctionData("immediateDelegateAllowance", [
            ethers.getAddress(formData.delegateAddress),
            formData.allowOnce
          ])
        }
      ]
      await sdk.txs.send({
        txs
      })
    } catch (error) {
      setErrorMessage('Failed to set immediate delegate allowance: ' + error)
    } finally {
      setLoading(false)
    }
  }, [safe, sdk]);

  return (
    <>
      <div>
        <a href="https://github.com/safe-research/guardrail" target="_blank">
          <img src={'./guardrailWhiteBorder.svg'} className="logo" alt="Guardrail logo" />
        </a>
      </div>
      <h1>Guardrail</h1>
      <div className="card">
        {loading ? (
          <p>Loading...</p>
        ) : !useSafeSdk.connected ? (
            <p>Not connected to any Safe</p>
        ): (
            <>
              {/* Enable or disable Guard */}
              <div>{guardRailInSafe ?
                removalTimestamp == 0n ? (
                    <div className="card">
                      <Alert severity="success" style={{margin:'1em'}}>Guardrail is Activated!</Alert>
                      <Button variant="contained" onClick={() => scheduleGuardrailRemoval()} disabled={loading}>
                        {loading ? 'Submitting transaction...' : 'Schedule Guardrail Removal'}
                      </Button>
                    </div>
                  ) : (
                    <div className="card">
                      {removalTimestamp > 0n && removalTimestamp < BigInt(Date.now()) ? (
                        <Button variant="contained" color="error" onClick={() => activateGuardrail(false)} disabled={loading}>
                          {loading ? 'Submitting transaction...' : 'Deactivate Guardrail'}
                        </Button>
                      ) : (
                        <>
                          <Alert severity="info" style={{margin:'1em'}}>Guardrail Removal Scheduled for {new Date(Number(removalTimestamp)).toLocaleString()}</Alert>
                          <Button variant="contained" color="error" style={{color:'grey',border:'1px solid',borderColor:'grey'}} disabled>
                            {'Deactivate Guardrail'}
                          </Button>                        
                        </>
                      )}
                    </div>
                  )
                :
                <div className="card">
                  <Button variant="contained" color="success" onClick={() => activateGuardrail(true)} disabled={loading}>
                    {loading ? 'Submitting transaction...' : 'Activate Guardrail'}
                  </Button>
                </div>
              }</div>
              <br />
              {/* Immediate or Schedule Delegate Allowance */}
              <div>{guardRailInSafe ? (
                  <>
                    <h2>Schedule Delegate Allowance</h2>
                    <form onSubmit={(e: React.FormEvent<HTMLFormElement>) => {
                      e.preventDefault()
                      const formData: ScheduleDelegateAllowanceFormData = {
                        delegateAddress: (e.currentTarget.elements.namedItem('delegateAddress') as HTMLInputElement).value,
                        allowOnce: (e.currentTarget.elements.namedItem('allowOnce') as HTMLInputElement).checked,
                        reset: false // As we are setting a new allowance
                      }
                      scheduleDelegateAllowance(formData)
                      } }>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                          <TextField 
                            slotProps={{
                              inputLabel: { style: { color: '#fff' } },
                              input: { style: { color: '#fff' } },
                            }}
                            sx={{ 
                              '& .MuiOutlinedInput-root': {
                                '& fieldset': {
                                  borderColor: '#fff',
                                },
                                '&:hover .MuiOutlinedInput-notchedOutline': {
                                  borderColor: '#fff',
                                  borderWidth: '0.15rem',
                                },
                              }
                            }}
                            variant="outlined" 
                            type="text" 
                            id="delegateAddress" 
                            name="delegateAddress" 
                            label="Delegate Address" 
                            required
                          />
                          <FormGroup>
                            <FormControlLabel
                              sx={{
                                '& .MuiCheckbox-root': { color: '#fff' }
                              }}
                              control={<Checkbox />} id="allowOnce" name="allowOnce" label="Allow Once" />
                          </FormGroup>
                          <Button variant='contained' color='primary' type="submit" disabled={loading}>
                            {loading ? 'Submitting...' : 'Schedule Allowance'}
                          </Button>
                        </div>
                    </form>
                  </>
                  ) : (
                    <>
                    <h2>Immediate Delegate Allowance</h2>
                    <form onSubmit={(e: React.FormEvent<HTMLFormElement>) => {
                      e.preventDefault()
                      const formData: ImmediateDelegateAllowanceFormData = {
                        delegateAddress: (e.currentTarget.elements.namedItem('delegateAddress') as HTMLInputElement).value,
                        allowOnce: (e.currentTarget.elements.namedItem('allowOnce') as HTMLInputElement).checked
                      }
                      immediateDelegateAllowance(formData)
                      } }>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                          <TextField 
                            slotProps={{
                              inputLabel: { style: { color: '#fff' } },
                              input: { style: { color: '#fff' } },
                            }}
                            sx={{ 
                              '& .MuiOutlinedInput-root': {
                                '& fieldset': {
                                  borderColor: '#fff',
                                },
                                '&:hover .MuiOutlinedInput-notchedOutline': {
                                  borderColor: '#fff',
                                  borderWidth: '0.15rem',
                                },
                              }
                            }}
                            variant="outlined" 
                            type="text" 
                            id="delegateAddress" 
                            name="delegateAddress" 
                            label="Delegate Address" 
                            required
                          />
                          <FormGroup>
                            <FormControlLabel
                              sx={{
                                '& .MuiCheckbox-root': { color: '#fff' }
                              }}
                              control={<Checkbox />} id="allowOnce" name="allowOnce" label="Allow Once" />
                          </FormGroup>
                          <Button variant='contained' color='primary' type="submit" disabled={loading}>
                            {loading ? 'Submitting...' : 'Schedule Allowance'}
                          </Button>
                        </div>
                    </form>
                    </>
                  )
                }
              </div>
              <br />
              {/* Current Delegates */}
              <div>{delegatesInfo.length > 0 ? (
                  <>
                  <h3>Showing current delegates</h3>
                  <TableContainer component={Paper}>
                      <Table sx={{ minWidth: 650 }} aria-label="delegates table">
                        <TableHead>
                          <TableRow>
                            <TableCell>Delegate Addresses</TableCell>
                            <TableCell>Active?</TableCell>
                            <TableCell>One Time?</TableCell>
                            <TableCell align="right"></TableCell>
                          </TableRow>
                        </TableHead>
                        <TableBody>
                          {delegatesInfo.map((delegate) => (
                            <TableRow
                              key={delegate.delegate}
                              sx={{ '&:last-child td, &:last-child th': { border: 0 } }}
                            >
                              <TableCell component="th" scope="row">
                                {delegate.delegate}
                              </TableCell>
                              <TableCell>
                                {delegate.allowedTimestamp < BigInt(Date.now()) ? 'Yes' : 'Will be active at ' + new Date(Number(delegate.allowedTimestamp)).toLocaleString()}
                              </TableCell>
                              <TableCell>
                                {delegate.oneTime ? 'Yes' : 'No'}
                              </TableCell>
                              <TableCell align="right">
                                <Button variant='contained' color='error' onClick={() => scheduleDelegateAllowance({ delegateAddress: delegate.delegate, allowOnce: false, reset: true })} disabled={loading}>
                                  {loading ? 'Submitting...' : 'Reset Allowance'}
                                </Button>
                              </TableCell>
                            </TableRow>
                          ))}
                        </TableBody>
                      </Table>
                    </TableContainer>                      
                    <p>Delegates count: {delegatesInfo.length}</p>
                  </>
                ) : (
                  <>
                    <h3>Showing current delegates</h3>
                    <TableContainer component={Paper}>
                      <Table sx={{ minWidth: 650 }} aria-label="delegates table">
                        <TableHead>
                          <TableRow>
                            <TableCell align='center'>No Delegates Found</TableCell>
                          </TableRow>
                        </TableHead>
                      </Table>
                    </TableContainer>
                  </>
                )
              }
              </div>
            </>
          )
        }
        {errorMessage ? (
          <p className="error">{errorMessage}</p>
        ) : null}
      </div>
    </>
  )
}

export default App
