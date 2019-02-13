require 'active_record'

ActiveRecord::Schema.define(:version => 20190112105149) do
  create_table "orbital_payment_methods", :force => true do |t|
    t.string   "kb_payment_method_id"      # NULL before Kill Bill knows about it
    t.string   "token"                     # orbital id
    t.string   "cc_first_name"
    t.string   "cc_last_name"
    t.string   "cc_type"
    t.string   "cc_exp_month"
    t.string   "cc_exp_year"
    t.string   "cc_number"
    t.string   "cc_last_4"
    t.string   "cc_start_month"
    t.string   "cc_start_year"
    t.string   "cc_issue_number"
    t.string   "cc_verification_value"
    t.string   "cc_track_data"
    t.string   "address1"
    t.string   "address2"
    t.string   "city"
    t.string   "state"
    t.string   "zip"
    t.string   "country"
    t.boolean  "is_deleted",               :null => false, :default => false
    t.datetime "created_at",               :null => false
    t.datetime "updated_at",               :null => false
    t.string   "kb_account_id"
    t.string   "kb_tenant_id"
  end

  add_index(:orbital_payment_methods, :kb_account_id)
  add_index(:orbital_payment_methods, :kb_payment_method_id)

  create_table "orbital_transactions", :force => true do |t|
    t.integer  "orbital_response_id",  :null => false
    t.string   "api_call",                       :null => false
    t.string   "kb_payment_id",                  :null => false
    t.string   "kb_payment_transaction_id",      :null => false
    t.string   "transaction_type",               :null => false
    t.string   "payment_processor_account_id"
    t.string   "txn_id"                          # orbital transaction id
    # Both null for void
    t.integer  "amount_in_cents"
    t.string   "currency"
    t.datetime "created_at",                     :null => false
    t.datetime "updated_at",                     :null => false
    t.string   "kb_account_id",                  :null => false
    t.string   "kb_tenant_id",                   :null => false
  end

  add_index(:orbital_transactions, :kb_payment_id)
  add_index(:orbital_transactions, :orbital_response_id)

  create_table "orbital_responses", :force => true do |t|
    t.string   "api_call",          :null => false
    t.string   "kb_payment_id"
    t.string   "kb_payment_transaction_id"
    t.string   "transaction_type"
    t.string   "payment_processor_account_id"
    t.text     "message"
    t.string   "authorization"
    t.boolean  "fraud_review"
    t.boolean  "test"
    t.string   "params_account_num"
    t.string   "params_address_1"
    t.string   "params_address_2"
    t.string   "params_approval_status"
    t.string   "params_auth_code"
    t.string   "params_avs_resp_code"
    t.string   "params_card_brand"
    t.string   "params_cavv_resp_code"
    t.string   "params_cc_account_num"
    t.string   "params_cc_expire_date"
    t.string   "params_country_fraud_filter_status"
    t.string   "params_customer_bin"
    t.string   "params_customer_city"
    t.string   "params_customer_country_code"
    t.string   "params_customer_email"
    t.string   "params_customer_merchant_id"
    t.string   "params_customer_name"
    t.string   "params_customer_phone"
    t.string   "params_customer_profile_action"
    t.string   "params_customer_profile_message"
    t.string   "params_customer_profile_order_override_ind"
    t.string   "params_customer_ref_num"
    t.string   "params_customer_state"
    t.string   "params_customer_zip"
    t.string   "params_cvv2_resp_code"
    t.string   "params_ecp_account_dda"
    t.string   "params_ecp_account_rt"
    t.string   "params_ecp_account_type"
    t.string   "params_host_avs_resp_code"
    t.string   "params_host_cvv2_resp_code"
    t.string   "params_host_resp_code"
    t.string   "params_industry_type"
    t.string   "params_iso_country_code"
    t.string   "params_merchant_id"
    t.string   "params_message_type"
    t.string   "params_order_default_amount"
    t.string   "params_order_default_description"
    t.string   "params_order_id"
    t.string   "params_partial_auth_occurred"
    t.string   "params_proc_status"
    t.string   "params_profile_proc_status"
    t.string   "params_recurring_advice_cd"
    t.string   "params_redeemed_amount"
    t.string   "params_remaining_balance"
    t.string   "params_requested_amount"
    t.string   "params_resp_code"
    t.string   "params_resp_msg"
    t.string   "params_resp_time"
    t.string   "params_status"
    t.string   "params_status_msg"
    t.string   "params_switch_solo_issue_num"
    t.string   "params_switch_solo_start_date"
    t.string   "params_terminal_id"
    t.string   "params_tx_ref_idx"
    t.string   "params_tx_ref_num"
    t.string   "params_trace_number"
    t.string   "params_mit_received_transaction_id"
    t.string   "avs_result_code"
    t.string   "avs_result_message"
    t.string   "avs_result_street_match"
    t.string   "avs_result_postal_match"
    t.string   "cvv_result_code"
    t.string   "cvv_result_message"
    t.boolean  "success"
    t.datetime "created_at",        :null => false
    t.datetime "updated_at",        :null => false
    t.string   "kb_account_id"
    t.string   "kb_tenant_id"
  end

  add_index(:orbital_responses, [:kb_payment_id, :kb_tenant_id])
  add_index(:orbital_responses, [:params_tx_ref_num, :kb_tenant_id])
  add_index(:orbital_responses, [:kb_payment_transaction_id, :kb_tenant_id])
end
