// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

// See https://learn.microsoft.com/rest/api/cost-management/scheduled-actions/create-or-update

targetScope = 'subscription'

//==============================================================================
// Parameters
//==============================================================================

@description('Name of the scheduled action used in the resource ID.')
param name string

@description('Indicates the kind of scheduled action. Default: Email.')
@allowed([
  'Email'
  'InsightAlert' // @subscription
])
param kind string = 'Email'

@description('Indicates whether the scheduled action is private and only editable by the current user. If false, the scheduled action will be shared with other users in the same scope. Ignored if kind is "InsightAlert". Default: false.')
param private bool = false

// @tenant
//   @description('Unique ID for the billingAccount this scheduled action should be created for. Only applicable for MCA or EA billing account scopes.')
//   param billingAccountId string = ''
//   @description('Unique ID for the billingProfile this scheduled action should be created for. Requires billingAccountId to be set.')
//   param billingProfileId string = ''
//   @description('Unique ID for the invoiceSection this scheduled action should be created for. Requires billingAccountId and billingProfileId to be set.')
//   param invoiceSectionId string = ''
//   @description('Unique ID for the customer this scheduled action should be created for. Requires billingAccountId to be set.')
//   param customerId string = ''
//   @description('Unique ID for the department this scheduled action should be created for. Requires billingAccountId to be set to the EA enrollment number.')
//   param departmentId string = ''
//   @description('Unique ID for the enrollmentAccount this scheduled action should be created for. Requires billingAccountId to be set to the EA enrollment number. departmentId is also required, if applicable.')
//   param enrollmentAccountId string = ''
//   @description('Unique ID for the AWS management account (aka external billing account) this scheduled action should be created for. Requires account to be setup with Connectors for AWS.')
//   param externalBillingAccountId string = ''
//   @description('Unique ID for the AWS member account (aka external subscription) this scheduled action should be created for. Requires account to be setup with Connectors for AWS.')
//   param externalSubscriptionId string = ''

@description('Specifies which built-in view to use. This is a shortcut for the full view ID.')
@allowed([
  ''
  'AccumulatedCosts'
  'CostByService'
  'DailyCosts'
])
param builtInView string = ''

@description('Required if kind is "Email" and builtInView is not set. The resource ID of the view to which the scheduled action will send. The view must either be private (tenant level) or owned by the same scope as the scheduled action. Ignored if kind is "InsightAlert" or if builtInView is set.')
param viewId string = ''

@description('The display name to show in the portal when viewing the list of scheduled actions. Default: (scheduled action name).')
param displayName string = name

@description('The status of the scheduled action. Default: Enabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param status string = 'Enabled'

@description('Email address of the person or team responsible for this scheduled action. This email address will be included in emails. Default: (email address of user deploying the template).')
param notificationEmail string

@description('List of email addresses that should receive emails. At least one valid email address is required.')
param emailRecipients array

@description('The subject of the email that will be sent to the email recipients. Default: (view name).')
@maxLength(70)
param emailSubject string = ''

@description('Include a message for recipients to add context about why they are getting the email, what to do, and/or who to contact. Default: "" (no message).')
@maxLength(250)
param emailMessage string = ''

@description('The language that will be used for the email template. Default: en.')
@allowed([
  'cs'
  'de'
  'en'
  'es'
  'fr'
  'hu'
  'id'
  'it'
  'ja'
  'ko'
  'nl'
  'pl'
  'pt-br'
  'pt-pt'
  'ru'
  'sv'
  'tr'
  'zh-hans'
  'zh-hant'
])
param emailLanguage string = 'en'

@description('The regional format that will be used for dates, times, and numbers. Default: en-us.')
@allowed([
  'cs-cz'
  'da-dk'
  'de-de'
  'en-gb'
  'en-us'
  'es-es'
  'fr-fr'
  'hu-hu'
  'id-id'
  'it-it'
  'ja-jp'
  'ko-kr'
  'nb-no'
  'nl-nl'
  'pl-pl'
  'pt-br'
  'pt-pt'
  'ru-ru'
  'sv-se'
  'tr-tr'
  'zh-cn'
  'zh-tw'
])
param emailRegionalFormat string = 'en-us'

@description('Indicates whether to include a link to a CSV file with the backing data for the chart. Ignored if kind is "InsightAlert". Default: false.')
param includeCsv bool = false

@description('The frequency at which the scheduled action will run. Default: Daily for "Email" and Weekly for "InsightAlert".')
@allowed([
  'Daily'
  'Weekly'
  'Monthly'
])
param scheduleFrequency string = kind == 'InsightAlert' ? 'Daily' : 'Weekly'

@description('Required if kind is "Email" and scheduleFrequency is "Weekly". List of days of the week that emails should be delivered. Allowed: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday. Default: Monday.')
param scheduleDaysOfWeek array = [ 'Monday' ]

@description('Required if kind is "Email" and scheduleFrequency is "Monthly". The day of the month that emails should be delivered. Note monthly cost is not final until the 3rd of the month. This or scheduleWeeksOfMonth is required if scheduleFrequency is "Monthly". Default: 0 (not set).')
@allowed([ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31 ])
param scheduleDayOfMonth int = 0

@description('List of weeks of the month that emails should be delivered. This or scheduleDayOfMonth is required if scheduleFrequency is "Monthly". Allowed: First, Second, Third, Fourth, Last. Default [] (not set).)')
param scheduleWeeksOfMonth array = []

@description('The first day the schedule should run. Use the time to indicate when you want to receive emails. Must be in the format yyyy-MM-ddTHH:miZ. Default = Now.')
param scheduleStartDate string = utcNow('yyyy-MM-ddTHH:00Z')

@description('The last day the schedule should run. Must be in the format yyyy-MM-dd. Default = 1 year from start date.')
param scheduleEndDate string = ''

//==============================================================================
// Variables
//==============================================================================

// @subscription
var scope = subscription().id
// @resourceGroup
//   var scope = resourceGroup().id
// @tenant
//   var useBillingAccount = !empty(billingAccountId) && empty(billingProfileId) && empty(customerId) && empty(departmentId) && empty(enrollmentAccountId)
//   var useBillingProfile = !empty(billingAccountId) && !empty(billingProfileId) && empty(invoiceSectionId)
//   var useInvoiceSection = !empty(billingAccountId) && !empty(billingProfileId) && !empty(invoiceSectionId)
//   var useCustomer = !empty(billingAccountId) && !empty(customerId)
//   var useDepartment = !empty(billingAccountId) && empty(billingProfileId) && empty(customerId) && !empty(departmentId) && empty(enrollmentAccountId)
//   var useEnrollmentAccount = !empty(billingAccountId) && empty(billingProfileId) && empty(customerId) && !empty(enrollmentAccountId)
//   var useExternalBillingAccount = empty(billingAccountId) && !empty(externalBillingAccountId)
//   var useExternalSubscription = empty(billingAccountId) && empty(externalBillingAccountId) && !empty(externalSubscriptionId)
//   var scope = !empty(privateScope) ? privateScope : useBillingAccount ? ba.id : useBillingProfile ? bp.id : useInvoiceSection ? is.id : useCustomer ? cust.id : useDepartment ? dept.id : useEnrollmentAccount ? ea.id : useExternalBillingAccount ? eba.id : useExternalSubscription ? es.id : tenant().tenantId

var internalViewId = builtInView == null ? viewId : '${scope}/providers/Microsoft.CostManagement/views/ms:${builtInView}'

//==============================================================================
// Resources
//==============================================================================

// @tenant
//   resource ba 'Microsoft.Billing/billingAccounts@2020-05-01' existing = if (useBillingAccount) {
//     name: billingAccountId
//   }
//   resource bp 'Microsoft.Billing/billingAccounts/billingProfiles@2020-05-01' existing = if (useBillingProfile) {
//     #disable-next-line use-parent-property // Would add extra complexity
//     name: '${billingAccountId}/${billingProfileId}'
//   }
//   resource is 'Microsoft.Billing/billingAccounts/billingProfiles/invoiceSections@2020-05-01' existing = if (useInvoiceSection) {
//     #disable-next-line use-parent-property // Would add extra complexity
//     name: '${billingAccountId}/${billingProfileId}/${invoiceSectionId}'
//   }
//   resource cust 'Microsoft.Billing/billingAccounts/customers@2020-05-01' existing = if (useCustomer) {
//     #disable-next-line use-parent-property // Would add extra complexity
//     name: '${billingAccountId}/${customerId}'
//   }
//   resource dept 'Microsoft.Billing/billingAccounts/departments@2019-10-01-preview' existing = if (useDepartment) {
//     #disable-next-line use-parent-property // Would add extra complexity
//     name: '${billingAccountId}/${departmentId}'
//   }
//   resource ea 'Microsoft.Billing/billingAccounts/enrollmentAccounts@2019-10-01-preview' existing = if (useEnrollmentAccount) {
//     #disable-next-line use-parent-property // Would add extra complexity
//     name: '${billingAccountId}/${enrollmentAccountId}'
//   }
//   resource eba 'Microsoft.CostManagement/externalBillingAccounts@2019-03-01-preview' existing = if (useExternalBillingAccount) {
//     name: externalBillingAccountId
//   }
//   resource es 'Microsoft.CostManagement/externalSubscriptions@2019-03-01-preview' existing = if (useExternalSubscription) {
//     name: externalSubscriptionId
//   }

resource sa 'Microsoft.CostManagement/scheduledActions@2022-10-01' = {
  name: name
  kind: kind
  scope: private ? tenant() : subscription() // @subscription
  // scope: private ? tenant() : resourceGroup() // @resourceGroup
  // scope: private ? tenant() : useBillingAccount ? ba : useBillingProfile ? bp : useInvoiceSection ? is : useCustomer ? cust : useDepartment ? dept : useEnrollmentAccount ? ea : useExternalBillingAccount ? eba : useExternalSubscription ? es : tenant() // @tenant
  properties: {
    scope: private ? scope : ''
    displayName: displayName
    viewId: kind == 'InsightAlert' ? '${scope}/providers/Microsoft.CostManagement/views/ms:DailyAnomalyByResourceGroup' : internalViewId
    notificationEmail: notificationEmail
    status: status
    fileDestination: includeCsv ? {
      fileFormats: [ 'Csv' ]
    } : {}
    notification: union(
      {
        subject: emailSubject != null && emailSubject != '' ? emailSubject : (displayName != null && displayName != '' ? displayName : name)
        to: emailRecipients
        language: emailLanguage
        regionalFormat: emailRegionalFormat
      },
      emailMessage == '' ? {} : { message: emailMessage }
    )
    schedule: union(
      {
        startDate: scheduleStartDate
        endDate: scheduleEndDate != null && scheduleEndDate != '' ? scheduleEndDate : dateTimeAdd(scheduleStartDate, 'P1Y')
        frequency: kind == 'InsightAlert' ? 'Daily' : scheduleFrequency
      },
      (kind == 'Email' && scheduleFrequency == 'Weekly') ? { daysOfWeek: scheduleDaysOfWeek } : {},
      (kind == 'Email' && scheduleFrequency == 'Monthly' && scheduleDayOfMonth != null) ? { dayOfMonth: scheduleDayOfMonth } : {},
      (kind == 'Email' && scheduleFrequency == 'Monthly' && scheduleDayOfMonth == null) ? { weeksOfMonth: scheduleWeeksOfMonth } : {}
    )
  }
}

//===| Outputs |===============================================================

@description('Resource ID of the scheduled action.')
output scheduledActionId string = sa.id
