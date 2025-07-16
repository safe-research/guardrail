import { useCallback, useEffect, useState } from 'react'
import './App.css'
import type { BaseTransaction } from '@safe-global/safe-apps-sdk'
import { useSafeAppsSDK } from '@safe-global/safe-apps-react-sdk'
import SafeAppsSDK from '@safe-global/safe-apps-sdk'
import { ethers } from 'ethers'
import Button from '@mui/material/Button'
import {
  Alert,
  Checkbox,
  FormControlLabel,
  FormGroup,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
} from '@mui/material'
import { CONTRACT_INTERFACE_ABI, GUARD_STORAGE_SLOT, GUARDRAIL_ADDRESS, MILLISECONDS_IN_SECOND, MULTISEND_CALL_ONLY } from './constants'
import type { ImmediateDelegateAllowanceFormData, ScheduleDelegateAllowanceFormData } from './types'

const CONTRACT_INTERFACE = new ethers.Interface(CONTRACT_INTERFACE_ABI)

const call = async (
  sdk: SafeAppsSDK,
  address: string,
  method: string,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  params: any[],
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
): Promise<any> => {
  const resp = await sdk.eth.call([
    {
      to: address,
      data: CONTRACT_INTERFACE.encodeFunctionData(method, params),
    },
  ])
  return CONTRACT_INTERFACE.decodeFunctionResult(method, resp)[0]
}

function App() {
  const [loading, setLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [txGuard, setTxGuard] = useState<string | null>(null)
  // const [moduleGuard, setModuleGuard] = useState<string | null>(null)
  const [guardRailInSafe, setGuardRailInSafe] = useState<boolean | null>(null)
  const [removalTimestamp, setRemovalTimestamp] = useState<bigint>(0n)
  const [delegatesInfo, setDelegatesInfo] = useState<
    { delegate: string; allowedTimestamp: bigint; oneTime: boolean }[]
  >([])
  const useSafeSdk = useSafeAppsSDK()
  const { safe, sdk } = useSafeSdk

  const safeConnected = useCallback(() => {
    setLoading(true)
    setErrorMessage(null)
    if (!safe) {
      setErrorMessage('No Safe connected')
      setLoading(false)
      return
    }
    setLoading(false)
  }, [safe])

  const fetchTxGuardInfo = useCallback(async () => {
    setLoading(true)
    setErrorMessage(null)
    try {
      // Get the Tx Guard
      const result = ethers.getAddress(
        '0x' +
          (
            await call(sdk, safe.safeAddress, 'getStorageAt', [
              GUARD_STORAGE_SLOT,
              1,
            ])
          ).slice(26),
      )
      setTxGuard(result)
    } catch (error) {
      setErrorMessage('Failed to fetch transaction guard with error: ' + error)
    } finally {
      setLoading(false)
    }
  }, [safe.safeAddress, sdk])

  // const fetchModuleGuardInfo = useCallback(async () => {
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
  // }, [safe.safeAddress, sdk])

  const fetchGuardRemovalInfo = useCallback(async () => {
    setLoading(true)
    setErrorMessage(null)
    try {
      // Check if the Tx Guard removal is already set
      const result = await call(sdk, GUARDRAIL_ADDRESS, 'removalSchedule', [
        ethers.getAddress(safe.safeAddress),
      ])
      if (result > 0n) {
        setRemovalTimestamp(result * MILLISECONDS_IN_SECOND) // Convert to milliseconds
      }
    } catch (error) {
      setErrorMessage('Failed to fetch guard removal info with error: ' + error)
    } finally {
      setLoading(false)
    }
  }, [safe.safeAddress, sdk])

  const fetchDelegateInfo = useCallback(
    async (delegate: string) => {
      setLoading(true)
      setErrorMessage(null)
      try {
        // Fetch the delegate allowance info
        const result = await call(
          sdk,
          GUARDRAIL_ADDRESS,
          'delegatedAllowance',
          [ethers.getAddress(safe.safeAddress), ethers.getAddress(delegate)],
        )
        console.log(
          `Delegate: ${delegate}, Allowed Timestamp: ${result.allowedTimestamp}, One Time: ${result.oneTimeAllowance}`,
        )
        return {
          delegate,
          allowedTimestamp: result.allowedTimestamp * MILLISECONDS_IN_SECOND, // Convert to milliseconds
          oneTime: result.oneTimeAllowance,
        }
      } catch (error) {
        setErrorMessage(
          'Failed to fetch delegate info for ' +
            delegate +
            ' with error: ' +
            error,
        )
      } finally {
        setLoading(false)
      }
    },
    [safe.safeAddress, sdk],
  )

  const fetchCurrentDelegates = useCallback(async () => {
    setLoading(true)
    setErrorMessage(null)

    try {
      // Fetch current delegates
      const result = await call(sdk, GUARDRAIL_ADDRESS, 'getDelegates', [
        ethers.getAddress(safe.safeAddress),
      ])

      // Convert proxy to array and then process addresses
      const delegatesArray = Array.from(result)
      let processedDelegates: string[] = []
      if (Array.isArray(delegatesArray)) {
        processedDelegates = delegatesArray.map((addr) =>
          ethers.getAddress(addr as string),
        )
      } else {
        setErrorMessage('Unexpected response format for delegates')
      }
      // Fetch delegate info for each delegate
      const delegateInfoPromises = processedDelegates.map((delegate) =>
        fetchDelegateInfo(delegate),
      )
      const delegateInfos = await Promise.all(delegateInfoPromises)
      // Filter out any null results (in case of errors)
      const validDelegateInfos = delegateInfos.filter(
        (info) => info !== null,
      ) as { delegate: string; allowedTimestamp: bigint; oneTime: boolean }[]
      setDelegatesInfo(validDelegateInfos)
    } catch (error) {
      setErrorMessage('Failed to fetch current delegates with error: ' + error)
    } finally {
      setLoading(false)
    }
  }, [fetchDelegateInfo, safe.safeAddress, sdk])

  useEffect(() => {
    safeConnected()
    if (safe && safe.safeAddress) {
      fetchTxGuardInfo()
      // fetchModuleGuardInfo()
      fetchGuardRemovalInfo()
      fetchCurrentDelegates()
    }
  }, [
    safe,
    sdk,
    safeConnected,
    fetchTxGuardInfo,
    /*fetchModuleGuardInfo,*/
    fetchGuardRemovalInfo,
    fetchCurrentDelegates,
  ])

  useEffect(() => {
    if (txGuard == GUARDRAIL_ADDRESS /* && moduleGuard == GUARDRAIL_ADDRESS*/) {
      setGuardRailInSafe(true)
    }
  }, [txGuard /*moduleGuard*/])

  const activateGuardrail = useCallback(
    async (activate: boolean) => {
      setLoading(true)
      setErrorMessage(null)
      const guardAddress = activate ? GUARDRAIL_ADDRESS : ethers.ZeroAddress
      const immediateMultiSendCallOnlyAllowance = {
        to: GUARDRAIL_ADDRESS,
        value: '0',
        data: CONTRACT_INTERFACE.encodeFunctionData(
          'immediateDelegateAllowance',
          [ethers.getAddress(MULTISEND_CALL_ONLY), false],
        ),
      }
      try {
        const txs: BaseTransaction[] = [
          ...(activate ? [immediateMultiSendCallOnlyAllowance] : []),
          {
            to: safe.safeAddress,
            value: '0',
            data: CONTRACT_INTERFACE.encodeFunctionData('setGuard', [
              guardAddress,
            ]),
          },
          // {
          //   to: safe.safeAddress,
          //   value: "0",
          //   data: CONTRACT_INTERFACE.encodeFunctionData("setModuleGuard", [guardAddress])
          // }
        ]
        await sdk.txs.send({
          txs,
        })
      } catch (error) {
        setErrorMessage('Failed to submit transaction: ' + error)
      } finally {
        setLoading(false)
      }
    },
    [safe, sdk],
  )

  const scheduleGuardrailRemoval = useCallback(async () => {
    setLoading(true)
    setErrorMessage(null)
    try {
      const txs: BaseTransaction[] = [
        {
          to: GUARDRAIL_ADDRESS,
          value: '0',
          data: CONTRACT_INTERFACE.encodeFunctionData('scheduleGuardRemoval'),
        },
      ]
      await sdk.txs.send({
        txs,
      })
      fetchGuardRemovalInfo() // Refresh the removal timestamp after scheduling
    } catch (error) {
      setErrorMessage('Failed to schedule guardrail removal: ' + error)
    } finally {
      setLoading(false)
    }
  }, [fetchGuardRemovalInfo, sdk.txs])

  const scheduleDelegateAllowance = useCallback(
    async (formData: ScheduleDelegateAllowanceFormData) => {
      setLoading(true)
      setErrorMessage(null)
      try {
        const txs: BaseTransaction[] = [
          {
            to: GUARDRAIL_ADDRESS,
            value: '0',
            data: CONTRACT_INTERFACE.encodeFunctionData('delegateAllowance', [
              ethers.getAddress(formData.delegateAddress),
              formData.allowOnce,
              formData.reset,
            ]),
          },
        ]
        await sdk.txs.send({
          txs,
        })
      } catch (error) {
        setErrorMessage('Failed to schedule delegate allowance: ' + error)
      } finally {
        setLoading(false)
      }
    },
    [sdk],
  )

  const immediateDelegateAllowance = useCallback(
    async (formData: ImmediateDelegateAllowanceFormData) => {
      setLoading(true)
      setErrorMessage(null)
      try {
        const txs: BaseTransaction[] = [
          {
            to: GUARDRAIL_ADDRESS,
            value: '0',
            data: CONTRACT_INTERFACE.encodeFunctionData(
              'immediateDelegateAllowance',
              [ethers.getAddress(formData.delegateAddress), formData.allowOnce],
            ),
          },
        ]
        await sdk.txs.send({
          txs,
        })
      } catch (error) {
        setErrorMessage('Failed to set immediate delegate allowance: ' + error)
      } finally {
        setLoading(false)
      }
    },
    [sdk],
  )

  return (
    <>
      <div>
        <a href="https://github.com/safe-research/guardrail" target="_blank">
          <img
            src={'./guardrailWhiteBorder.svg'}
            className="logo"
            alt="Guardrail logo"
          />
        </a>
      </div>
      <h1>Guardrail</h1>
      <div className="card">
        {loading ? (
          <p>Loading...</p>
        ) : !useSafeSdk.connected ? (
          <p>Not connected to any Safe</p>
        ) : (
          <>
            {/* Enable or disable Guard */}
            <div>
              {guardRailInSafe ? (
                removalTimestamp == 0n ? (
                  <div className="card">
                    <Alert severity="success" style={{ margin: '1em' }}>
                      Guardrail is Activated!
                    </Alert>
                    <Button
                      variant="contained"
                      onClick={() => scheduleGuardrailRemoval()}
                      disabled={loading}
                    >
                      {loading
                        ? 'Submitting transaction...'
                        : 'Schedule Guardrail Removal'}
                    </Button>
                  </div>
                ) : (
                  <div className="card">
                    {removalTimestamp > 0n &&
                    removalTimestamp < BigInt(Date.now()) ? (
                      <Button
                        variant="contained"
                        color="error"
                        onClick={() => activateGuardrail(false)}
                        disabled={loading}
                      >
                        {loading
                          ? 'Submitting transaction...'
                          : 'Deactivate Guardrail'}
                      </Button>
                    ) : (
                      <>
                        <Alert severity="info" style={{ margin: '1em' }}>
                          Guardrail Removal Scheduled for{' '}
                          {new Date(Number(removalTimestamp)).toLocaleString()}
                        </Alert>
                        <Button
                          variant="contained"
                          color="error"
                          style={{
                            color: 'grey',
                            border: '1px solid',
                            borderColor: 'grey',
                          }}
                          disabled
                        >
                          {'Deactivate Guardrail'}
                        </Button>
                      </>
                    )}
                  </div>
                )
              ) : (
                <div className="card">
                  <Button
                    variant="contained"
                    color="success"
                    onClick={() => activateGuardrail(true)}
                    disabled={loading}
                  >
                    {loading
                      ? 'Submitting transaction...'
                      : 'Activate Guardrail'}
                  </Button>
                </div>
              )}
            </div>
            <br />
            {/* Immediate or Schedule Delegate Allowance */}
            <div>
              {guardRailInSafe ? (
                <>
                  <h2>Schedule Delegate Allowance</h2>
                  <form
                    onSubmit={(e: React.FormEvent<HTMLFormElement>) => {
                      e.preventDefault()
                      const formData: ScheduleDelegateAllowanceFormData = {
                        delegateAddress: (
                          e.currentTarget.elements.namedItem(
                            'delegateAddress',
                          ) as HTMLInputElement
                        ).value,
                        allowOnce: (
                          e.currentTarget.elements.namedItem(
                            'allowOnce',
                          ) as HTMLInputElement
                        ).checked,
                        reset: false, // As we are setting a new allowance
                      }
                      scheduleDelegateAllowance(formData)
                    }}
                  >
                    <div
                      style={{
                        display: 'flex',
                        flexDirection: 'column',
                        gap: '10px',
                      }}
                    >
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
                          },
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
                            '& .MuiCheckbox-root': { color: '#fff' },
                          }}
                          control={<Checkbox />}
                          id="allowOnce"
                          name="allowOnce"
                          label="Allow Once"
                        />
                      </FormGroup>
                      <Button
                        variant="contained"
                        color="primary"
                        type="submit"
                        disabled={loading}
                      >
                        {loading ? 'Submitting...' : 'Schedule Allowance'}
                      </Button>
                    </div>
                  </form>
                </>
              ) : (
                <>
                  <h2>Immediate Delegate Allowance</h2>
                  <form
                    onSubmit={(e: React.FormEvent<HTMLFormElement>) => {
                      e.preventDefault()
                      const formData: ImmediateDelegateAllowanceFormData = {
                        delegateAddress: (
                          e.currentTarget.elements.namedItem(
                            'delegateAddress',
                          ) as HTMLInputElement
                        ).value,
                        allowOnce: (
                          e.currentTarget.elements.namedItem(
                            'allowOnce',
                          ) as HTMLInputElement
                        ).checked,
                      }
                      immediateDelegateAllowance(formData)
                    }}
                  >
                    <div
                      style={{
                        display: 'flex',
                        flexDirection: 'column',
                        gap: '10px',
                      }}
                    >
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
                          },
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
                            '& .MuiCheckbox-root': { color: '#fff' },
                          }}
                          control={<Checkbox />}
                          id="allowOnce"
                          name="allowOnce"
                          label="Allow Once"
                        />
                      </FormGroup>
                      <Button
                        variant="contained"
                        color="primary"
                        type="submit"
                        disabled={loading}
                      >
                        {loading ? 'Submitting...' : 'Schedule Allowance'}
                      </Button>
                    </div>
                  </form>
                </>
              )}
            </div>
            <br />
            {/* Current Delegates */}
            <div>
              {delegatesInfo.length > 0 ? (
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
                            sx={{
                              '&:last-child td, &:last-child th': { border: 0 },
                            }}
                          >
                            <TableCell component="th" scope="row">
                              {delegate.delegate}
                            </TableCell>
                            <TableCell>
                              {delegate.allowedTimestamp < BigInt(Date.now())
                                ? 'Yes'
                                : 'Will be active at ' +
                                  new Date(
                                    Number(delegate.allowedTimestamp),
                                  ).toLocaleString()}
                            </TableCell>
                            <TableCell>
                              {delegate.oneTime ? 'Yes' : 'No'}
                            </TableCell>
                            <TableCell align="right">
                              <Button
                                variant="contained"
                                color="error"
                                onClick={() =>
                                  scheduleDelegateAllowance({
                                    delegateAddress: delegate.delegate,
                                    allowOnce: false,
                                    reset: true,
                                  })
                                }
                                disabled={loading}
                              >
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
                          <TableCell align="center">
                            No Delegates Found
                          </TableCell>
                        </TableRow>
                      </TableHead>
                    </Table>
                  </TableContainer>
                </>
              )}
            </div>
          </>
        )}
        {errorMessage ? <p className="error">{errorMessage}</p> : null}
      </div>
    </>
  )
}

export default App
