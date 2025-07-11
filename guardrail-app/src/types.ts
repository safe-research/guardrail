// Type definitions for the Guardrail app

export interface ImmediateDelegateAllowanceFormData {
  delegateAddress: string
  allowOnce: boolean
}

export interface ScheduleDelegateAllowanceFormData
  extends ImmediateDelegateAllowanceFormData {
  reset: boolean
}
