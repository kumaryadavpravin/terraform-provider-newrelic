package newrelic

import (
	"context"
	"fmt"
	"strings"

	"github.com/hashicorp/terraform-plugin-sdk/v2/diag"
	"github.com/hashicorp/terraform-plugin-sdk/v2/helper/schema"
)

const cciAzureIntegrationCreateMutation = `
mutation($accountId: Int!, $azureIntegration: AzureIntegration, $filters: [IntegrationFilter]) {
  integrationCreate(
    accountId: $accountId
    azureIntegration: $azureIntegration
    filters: $filters
  ) {
    id
    name
    enabled
    status
    scheduleId
    azure {
      agreementType
      tenantId
      storageAccountName
      containerName
      billingAccountId
      baseDropPath
    }
  }
}`

const cciAzureIntegrationDeleteMutation = `
mutation($accountId: Int!, $deleteIntegrationDetails: DeleteIntegrationInput!) {
  integrationDelete(
    accountId: $accountId
    deleteIntegrationDetails: $deleteIntegrationDetails
  ) {
    success
    errors
  }
}`

const cciAzureIntegrationsQuery = `
query($filters: [IntegrationFilter]) {
  cloudCostIntelligence {
    integrations(filters: $filters) {
      items {
        id
        name
        enabled
        status
        scheduleId
        azure {
          agreementType
          tenantId
          storageAccountName
          containerName
          billingAccountId
          baseDropPath
        }
      }
    }
  }
}`

type cciAzureConfig struct {
	AgreementType      string `json:"agreementType"`
	TenantID           string `json:"tenantId"`
	StorageAccountName string `json:"storageAccountName"`
	ContainerName      string `json:"containerName"`
	BillingAccountID   string `json:"billingAccountId"`
	BaseDropPath       string `json:"baseDropPath"`
}

type cciIntegrationItem struct {
	ID         string         `json:"id"`
	Name       string         `json:"name"`
	Enabled    bool           `json:"enabled"`
	Status     string         `json:"status"`
	ScheduleID string         `json:"scheduleId"`
	Azure      *cciAzureConfig `json:"azure"`
}

type cciCreateResponse struct {
	CloudCostIntelligenceIntegrationCreate cciIntegrationItem `json:"cloudCostIntelligenceIntegrationCreate"`
}

type cciQueryResponse struct {
	CloudCostIntelligence struct {
		Integrations struct {
			Items []cciIntegrationItem `json:"items"`
		} `json:"integrations"`
	} `json:"cloudCostIntelligence"`
}

func resourceNewRelicCloudCciAzureIntegration() *schema.Resource {
	return &schema.Resource{
		CreateContext: resourceNewRelicCloudCciAzureIntegrationCreate,
		ReadContext:   resourceNewRelicCloudCciAzureIntegrationRead,
		UpdateContext: resourceNewRelicCloudCciAzureIntegrationUpdate,
		DeleteContext: resourceNewRelicCloudCciAzureIntegrationDelete,
		Importer: &schema.ResourceImporter{
			StateContext: resourceNewRelicCloudCciAzureIntegrationImport,
		},
		Schema: map[string]*schema.Schema{
			"account_id": {
				Type:        schema.TypeInt,
				Optional:    true,
				Computed:    true,
				Description: "The New Relic account ID. Defaults to the provider account if not set.",
			},
			"connection_name": {
				Type:        schema.TypeString,
				Required:    true,
				ForceNew:    true,
				Description: "Unique connection name identifying this CCI Azure integration.",
			},
			"agreement_type": {
				Type:        schema.TypeString,
				Required:    true,
				Description: "Azure agreement type: 'Enterprise Agreement' or 'Microsoft Customer Agreement'.",
			},
			"tenant_id": {
				Type:        schema.TypeString,
				Required:    true,
				Description: "Azure tenant (Directory) ID.",
			},
			"storage_account_name": {
				Type:        schema.TypeString,
				Required:    true,
				Description: "Name of the Azure storage account containing billing cost data.",
			},
			"container_name": {
				Type:        schema.TypeString,
				Required:    true,
				Description: "Name of the storage container holding billing data.",
			},
			"billing_account_id": {
				Type:        schema.TypeString,
				Optional:    true,
				Description: "Azure billing account ID (EA/MCA).",
			},
			"base_drop_path": {
				Type:        schema.TypeString,
				Optional:    true,
				Default:     "",
				Description: "Base path within the container for monthly billing drops.",
			},
			"status": {
				Type:        schema.TypeString,
				Computed:    true,
				Description: "Validation status: NOT_EVALUATED, ACTIVE, or FAILED.",
			},
			"schedule_id": {
				Type:        schema.TypeString,
				Computed:    true,
				Description: "CCI internal schedule ID.",
			},
			"integration_id": {
				Type:        schema.TypeString,
				Computed:    true,
				Description: "CCI integration ID.",
			},
		},
	}
}

func resourceNewRelicCloudCciAzureIntegrationCreate(ctx context.Context, d *schema.ResourceData, meta interface{}) diag.Diagnostics {
	providerConfig := meta.(*ProviderConfig)
	client := providerConfig.NewClient
	accountID := selectAccountID(providerConfig, d)

	variables := map[string]interface{}{
		"accountId":        accountID,
		"azureIntegration": expandCciAzureIntegrationInput(d),
	}

	var resp cciCreateResponse
	if err := client.NerdGraph.QueryWithResponseAndContext(ctx, cciAzureIntegrationCreateMutation, variables, &resp); err != nil {
		return diag.FromErr(fmt.Errorf("error creating CCI Azure integration: %w", err))
	}

	item := resp.CloudCostIntelligenceIntegrationCreate
	d.SetId(fmt.Sprintf("%d:%s", accountID, d.Get("connection_name").(string)))
	_ = d.Set("account_id", accountID)
	_ = d.Set("integration_id", item.ID)
	_ = d.Set("status", item.Status)
	_ = d.Set("schedule_id", item.ScheduleID)

	return nil
}

func resourceNewRelicCloudCciAzureIntegrationRead(ctx context.Context, d *schema.ResourceData, meta interface{}) diag.Diagnostics {
	providerConfig := meta.(*ProviderConfig)
	client := providerConfig.NewClient

	connectionName := d.Get("connection_name").(string)

	variables := map[string]interface{}{
		"filters": []map[string]interface{}{
			{"term": "cloudProvider", "value": []string{"Azure"}, "operator": "EQ"},
			{"term": "name", "value": []string{connectionName}, "operator": "EQ"},
		},
	}

	var resp cciQueryResponse
	if err := client.NerdGraph.QueryWithResponseAndContext(ctx, cciAzureIntegrationsQuery, variables, &resp); err != nil {
		return diag.FromErr(fmt.Errorf("error reading CCI Azure integration: %w", err))
	}

	items := resp.CloudCostIntelligence.Integrations.Items
	if len(items) == 0 {
		d.SetId("")
		return nil
	}

	item := items[0]
	_ = d.Set("status", item.Status)
	_ = d.Set("schedule_id", item.ScheduleID)
	_ = d.Set("integration_id", item.ID)

	if item.Azure != nil {
		_ = d.Set("agreement_type", item.Azure.AgreementType)
		_ = d.Set("tenant_id", item.Azure.TenantID)
		_ = d.Set("storage_account_name", item.Azure.StorageAccountName)
		_ = d.Set("container_name", item.Azure.ContainerName)
		_ = d.Set("billing_account_id", item.Azure.BillingAccountID)
		_ = d.Set("base_drop_path", item.Azure.BaseDropPath)
	}

	return nil
}

func resourceNewRelicCloudCciAzureIntegrationUpdate(ctx context.Context, d *schema.ResourceData, meta interface{}) diag.Diagnostics {
	providerConfig := meta.(*ProviderConfig)
	client := providerConfig.NewClient
	accountID := selectAccountID(providerConfig, d)

	variables := map[string]interface{}{
		"accountId":        accountID,
		"azureIntegration": expandCciAzureIntegrationInput(d),
		"filters": []map[string]interface{}{
			{"term": "update", "value": []string{"true"}, "operator": "EQ"},
		},
	}

	var resp cciCreateResponse
	if err := client.NerdGraph.QueryWithResponseAndContext(ctx, cciAzureIntegrationCreateMutation, variables, &resp); err != nil {
		return diag.FromErr(fmt.Errorf("error updating CCI Azure integration: %w", err))
	}

	item := resp.CloudCostIntelligenceIntegrationCreate
	_ = d.Set("status", item.Status)
	_ = d.Set("schedule_id", item.ScheduleID)

	return resourceNewRelicCloudCciAzureIntegrationRead(ctx, d, meta)
}

func resourceNewRelicCloudCciAzureIntegrationDelete(ctx context.Context, d *schema.ResourceData, meta interface{}) diag.Diagnostics {
	providerConfig := meta.(*ProviderConfig)
	client := providerConfig.NewClient
	accountID := selectAccountID(providerConfig, d)

	variables := map[string]interface{}{
		"accountId": accountID,
		"deleteIntegrationDetails": map[string]interface{}{
			"connectionName": d.Get("connection_name").(string),
			"cloudProvider":  "AZURE",
		},
	}

	var resp interface{}
	if err := client.NerdGraph.QueryWithResponseAndContext(ctx, cciAzureIntegrationDeleteMutation, variables, &resp); err != nil {
		return diag.FromErr(fmt.Errorf("error deleting CCI Azure integration: %w", err))
	}

	d.SetId("")
	return nil
}

func resourceNewRelicCloudCciAzureIntegrationImport(ctx context.Context, d *schema.ResourceData, meta interface{}) ([]*schema.ResourceData, error) {
	parts := strings.SplitN(d.Id(), ":", 2)
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		return nil, fmt.Errorf("invalid import ID: expected '<account_id>:<connection_name>', got: %s", d.Id())
	}

	var accountID int
	if _, err := fmt.Sscanf(parts[0], "%d", &accountID); err != nil {
		return nil, fmt.Errorf("invalid account ID in import ID: %s", parts[0])
	}

	_ = d.Set("account_id", accountID)
	_ = d.Set("connection_name", parts[1])

	diags := resourceNewRelicCloudCciAzureIntegrationRead(ctx, d, meta)
	if diags.HasError() {
		return nil, fmt.Errorf("error reading CCI Azure integration during import: %v", diags)
	}

	return []*schema.ResourceData{d}, nil
}

func expandCciAzureIntegrationInput(d *schema.ResourceData) map[string]interface{} {
	input := map[string]interface{}{
		"connectionName":     d.Get("connection_name").(string),
		"agreementType":      d.Get("agreement_type").(string),
		"tenantId":           d.Get("tenant_id").(string),
		"storageAccountName": d.Get("storage_account_name").(string),
		"containerName":      d.Get("container_name").(string),
		"baseDropPath":       d.Get("base_drop_path").(string),
	}

	if v, ok := d.GetOk("billing_account_id"); ok && v.(string) != "" {
		input["billingAccountId"] = v.(string)
	}

	return input
}
