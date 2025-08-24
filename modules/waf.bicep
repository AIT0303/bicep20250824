param name string
param location string
param tags object = {}

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2023-11-01' = {
  name: name
  location: location // Application Gateway WAFはリージョナルリソースです
  properties: {
    customRules: [
      {
        name: 'CustomRule1'
        priority: 1
        ruleType: 'MatchRule'
        action: 'Block'
        state: 'Enabled'
        matchConditions: [
          {
            matchVariables: [
              {
                variableName: 'RemoteAddr'
              }
            ]
            operator: 'IPMatch'
            matchValues: [
              '192.168.1.0/24'
            ]
            negationConditon: false
            transforms: []
          }
        ]
        groupByUserSession: []
        rateLimitDuration: 'OneMin'
        rateLimitThreshold: 0
      }
    ]
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
          ruleGroupOverrides: []
        }
      ]
      exclusions: []
    }
    policySettings: {
      state: 'Enabled'
      mode: 'Prevention'
      requestBodyCheck: true
      requestBodyInspectLimitInKB: 128
      requestBodyEnforcement: true
      maxRequestBodySizeInKb: 128
      fileUploadEnforcement: true
      fileUploadLimitInMb: 100
      customBlockResponseStatusCode: 403
      logScrubbing: {
        state: 'Disabled'
        scrubbingRules: []
      }
      jsChallengeCookieExpirationInMins: 30
    }
  }
  tags: tags
}

output wafPolicyId string = wafPolicy.id
