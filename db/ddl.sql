CREATE TABLE orbital_payment_methods (
  id serial UNIQUE,
  kb_payment_method_id varchar(255) DEFAULT NULL,
  token varchar(255) DEFAULT NULL,
  cc_first_name varchar(255) DEFAULT NULL,
  cc_last_name varchar(255) DEFAULT NULL,
  cc_type varchar(255) DEFAULT NULL,
  cc_exp_month varchar(255) DEFAULT NULL,
  cc_exp_year varchar(255) DEFAULT NULL,
  cc_number varchar(255) DEFAULT NULL,
  cc_last_4 varchar(255) DEFAULT NULL,
  cc_start_month varchar(255) DEFAULT NULL,
  cc_start_year varchar(255) DEFAULT NULL,
  cc_issue_number varchar(255) DEFAULT NULL,
  cc_verification_value varchar(255) DEFAULT NULL,
  cc_track_data varchar(255) DEFAULT NULL,
  address1 varchar(255) DEFAULT NULL,
  address2 varchar(255) DEFAULT NULL,
  city varchar(255) DEFAULT NULL,
  state varchar(255) DEFAULT NULL,
  zip varchar(255) DEFAULT NULL,
  country varchar(255) DEFAULT NULL,
  is_deleted boolean NOT NULL DEFAULT '0',
  created_at datetime NOT NULL,
  updated_at datetime NOT NULL,
  kb_account_id varchar(255) DEFAULT NULL,
  kb_tenant_id varchar(255) DEFAULT NULL,
  PRIMARY KEY (id)
) /*! ENGINE=InnoDB CHARACTER SET utf8 COLLATE utf8_bin */;
CREATE INDEX index_orbital_payment_methods_kb_account_id ON orbital_payment_methods(kb_account_id);
CREATE INDEX index_orbital_payment_methods_kb_payment_method_id ON orbital_payment_methods(kb_payment_method_id);

CREATE TABLE orbital_transactions (
  id serial UNIQUE,
  orbital_response_id bigint /*! unsigned */ NOT NULL,
  api_call varchar(255) NOT NULL,
  kb_payment_id varchar(255) NOT NULL,
  kb_payment_transaction_id varchar(255) NOT NULL,
  transaction_type varchar(255) NOT NULL,
  payment_processor_account_id varchar(255) DEFAULT NULL,
  txn_id varchar(255) DEFAULT NULL,
  amount_in_cents int DEFAULT NULL,
  currency varchar(255) DEFAULT NULL,
  created_at datetime NOT NULL,
  updated_at datetime NOT NULL,
  kb_account_id varchar(255) NOT NULL,
  kb_tenant_id varchar(255) NOT NULL,
  PRIMARY KEY (id)
) /*! ENGINE=InnoDB CHARACTER SET utf8 COLLATE utf8_bin */;
CREATE INDEX index_orbital_transactions_kb_payment_id ON orbital_transactions(kb_payment_id);
CREATE INDEX index_orbital_transactions_orbital_response_id ON orbital_transactions(orbital_response_id);

CREATE TABLE orbital_responses (
  id serial UNIQUE,
  api_call varchar(255) NOT NULL,
  kb_payment_id varchar(255) DEFAULT NULL,
  kb_payment_transaction_id varchar(255) DEFAULT NULL,
  transaction_type varchar(255) DEFAULT NULL,
  payment_processor_account_id varchar(255) DEFAULT NULL,
  message text DEFAULT NULL,
  authorisation varchar(255) DEFAULT NULL,
  fraud_review boolean DEFAULT NULL,
  test boolean DEFAULT NULL,
  params_account_num varchar(255) DEFAULT NULL,
  params_address_1 varchar(255) DEFAULT NULL,
  params_address_2 varchar(255) DEFAULT NULL,
  params_approval_status varchar(255) DEFAULT NULL,
  params_auth_code varchar(255) DEFAULT NULL,
  params_avs_resp_code varchar(255) DEFAULT NULL,
  params_card_brand varchar(255) DEFAULT NULL,
  params_cavv_resp_code varchar(255) DEFAULT NULL,
  params_cc_account_num varchar(255) DEFAULT NULL,
  params_cc_expire_date varchar(255) DEFAULT NULL,
  params_country_fraud_filter_status varchar(255) DEFAULT NULL,
  params_customer_bin varchar(255) DEFAULT NULL,
  params_customer_city varchar(255) DEFAULT NULL,
  params_customer_country_code varchar(255) DEFAULT NULL,
  params_customer_email varchar(255) DEFAULT NULL,
  params_customer_merchant_id varchar(255) DEFAULT NULL,
  params_customer_name varchar(255) DEFAULT NULL,
  params_customer_phone varchar(255) DEFAULT NULL,
  params_customer_profile_action varchar(255) DEFAULT NULL,
  params_customer_profile_message varchar(255) DEFAULT NULL,
  params_customer_profile_order_override_ind varchar(255) DEFAULT NULL,
  params_customer_ref_num varchar(255) DEFAULT NULL,
  params_customer_state varchar(255) DEFAULT NULL,
  params_customer_zip varchar(255) DEFAULT NULL,
  params_cvv2_resp_code varchar(255) DEFAULT NULL,
  params_ecp_account_dda varchar(255) DEFAULT NULL,
  params_ecp_account_rt varchar(255) DEFAULT NULL,
  params_ecp_account_type varchar(255) DEFAULT NULL,
  params_ecp_bank_pmt_dlv varchar(255) DEFAULT NULL,
  params_host_avs_resp_code varchar(255) DEFAULT NULL,
  params_host_cvv2_resp_code varchar(255) DEFAULT NULL,
  params_host_resp_code varchar(255) DEFAULT NULL,
  params_industry_type varchar(255) DEFAULT NULL,
  params_iso_country_code varchar(255) DEFAULT NULL,
  params_merchant_id varchar(255) DEFAULT NULL,
  params_message_type varchar(255) DEFAULT NULL,
  params_order_default_amount varchar(255) DEFAULT NULL,
  params_order_default_description varchar(255) DEFAULT NULL,
  params_order_id varchar(255) DEFAULT NULL,
  params_partial_auth_occurred varchar(255) DEFAULT NULL,
  params_proc_status varchar(255) DEFAULT NULL,
  params_profile_proc_status varchar(255) DEFAULT NULL,
  params_recurring_advice_cd varchar(255) DEFAULT NULL,
  params_redeemed_amount varchar(255) DEFAULT NULL,
  params_remaining_balance varchar(255) DEFAULT NULL,
  params_requested_amount varchar(255) DEFAULT NULL,
  params_resp_code varchar(255) DEFAULT NULL,
  params_resp_msg varchar(255) DEFAULT NULL,
  params_resp_time varchar(255) DEFAULT NULL,
  params_status varchar(255) DEFAULT NULL,
  params_status_msg varchar(255) DEFAULT NULL,
  params_switch_solo_issue_num varchar(255) DEFAULT NULL,
  params_switch_solo_start_date varchar(255) DEFAULT NULL,
  params_terminal_id varchar(255) DEFAULT NULL,
  params_tx_ref_idx varchar(255) DEFAULT NULL,
  params_tx_ref_num varchar(255) DEFAULT NULL,
  params_trace_number varchar(16) DEFAULT NULL,
  avs_result_code varchar(255) DEFAULT NULL,
  avs_result_message varchar(255) DEFAULT NULL,
  avs_result_street_match varchar(255) DEFAULT NULL,
  avs_result_postal_match varchar(255) DEFAULT NULL,
  cvv_result_code varchar(255) DEFAULT NULL,
  cvv_result_message varchar(255) DEFAULT NULL,
  success boolean DEFAULT NULL,
  created_at datetime NOT NULL,
  updated_at datetime NOT NULL,
  kb_account_id varchar(255) DEFAULT NULL,
  kb_tenant_id varchar(255) DEFAULT NULL,
  PRIMARY KEY (id)
) /*! ENGINE=InnoDB CHARACTER SET utf8 COLLATE utf8_bin */;
CREATE INDEX index_orbital_responses_kb_payment_id_kb_tenant_id ON orbital_responses(kb_payment_id, kb_tenant_id);
CREATE INDEX index_orbital_responses_kb_payment_txn_id_kb_tenant_id ON orbital_responses(kb_payment_transaction_id, kb_tenant_id);
CREATE INDEX index_orbital_responses_params_tx_ref_num_kb_tenant_id ON orbital_responses(params_tx_ref_num, kb_tenant_id);