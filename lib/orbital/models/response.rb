module Killbill #:nodoc:
  module Orbital #:nodoc:
    class OrbitalResponse < ::Killbill::Plugin::ActiveMerchant::ActiveRecord::Response

      self.table_name = 'orbital_responses'

      has_one :orbital_transaction

      def self.from_response(api_call, kb_account_id, kb_payment_id, kb_payment_transaction_id, transaction_type, payment_processor_account_id, kb_tenant_id, response, extra_params = {}, model = ::Killbill::Orbital::OrbitalResponse)
        super(api_call,
              kb_account_id,
              kb_payment_id,
              kb_payment_transaction_id,
              transaction_type,
              payment_processor_account_id,
              kb_tenant_id,
              response,
              orbital_response_params(response).merge!(extra_params),
              model)
      end

      def self.orbital_response_params(response)
        {
          :params_account_num => extract(response, 'account_num'),
          :params_address_1 => extract(response, 'address_1'),
          :params_address_2 => extract(response, 'address_2'),
          :params_approval_status => extract(response, 'approval_status'),
          :params_auth_code => extract(response, 'auth_code'),
          :params_avs_resp_code => extract(response, 'avs_resp_code'),
          :params_card_brand => extract(response, 'card_brand'),
          :params_cavv_resp_code => extract(response, 'cavv_resp_code'),
          :params_cc_account_num => extract(response, 'cc_account_num'),
          :params_cc_expire_date => extract(response, 'cc_expire_date'),
          :params_country_fraud_filter_status => extract(response, 'country_fraud_filter_status'),
          :params_customer_bin => extract(response, 'customer_bin'),
          :params_customer_city => extract(response, 'customer_city'),
          :params_customer_country_code => extract(response, 'customer_country_code'),
          :params_customer_email => extract(response, 'customer_email'),
          :params_customer_merchant_id => extract(response, 'customer_merchant_id'),
          :params_customer_name => extract(response, 'customer_name'),
          :params_customer_phone => extract(response, 'customer_phone'),
          :params_customer_profile_action => extract(response, 'customer_profile_action'),
          :params_customer_profile_message => extract(response, 'customer_profile_message'),
          :params_customer_profile_order_override_ind => extract(response, 'customer_profile_order_override_ind'),
          :params_customer_ref_num => extract(response, 'customer_ref_num'),
          :params_customer_state => extract(response, 'customer_state'),
          :params_customer_zip => extract(response, 'customer_zip'),
          :params_cvv2_resp_code => extract(response, 'cvv2_resp_code'),
          :params_ecp_account_dda => extract(response, 'ecp_account_dda'),
          :params_ecp_account_rt => extract(response, 'ecp_account_rt'),
          :params_ecp_account_type => extract(response, 'ecp_account_type'),
          :params_ecp_bank_pmt_dlv => extract(response, 'ecp_bank_pmt_dlv'),
          :params_host_avs_resp_code => extract(response, 'host_avs_resp_code'),
          :params_host_cvv2_resp_code => extract(response, 'host_cvv2_resp_code'),
          :params_host_resp_code => extract(response, 'host_resp_code'),
          :params_industry_type => extract(response, 'industry_type'),
          :params_iso_country_code => extract(response, 'iso_country_code'),
          :params_merchant_id => extract(response, 'merchant_id'),
          :params_message_type => extract(response, 'message_type'),
          :params_order_default_amount => extract(response, 'order_default_amount'),
          :params_order_default_description => extract(response, 'order_default_description'),
          :params_order_id => extract(response, 'order_id'),
          :params_partial_auth_occurred => extract(response, 'partial_auth_occurred'),
          :params_proc_status => extract(response, 'proc_status'),
          :params_profile_proc_status => extract(response, 'profile_proc_status'),
          :params_recurring_advice_cd => extract(response, 'recurring_advice_cd'),
          :params_redeemed_amount => extract(response, 'redeemed_amount'),
          :params_remaining_balance => extract(response, 'remaining_balance'),
          :params_requested_amount => extract(response, 'requested_amount'),
          :params_resp_code => extract(response, 'resp_code'),
          :params_resp_msg => extract(response, 'resp_msg'),
          :params_resp_time => extract(response, 'resp_time'),
          :params_status => extract(response, 'status'),
          :params_status_msg => extract(response, 'status_msg'),
          :params_switch_solo_issue_num => extract(response, 'switch_solo_issue_num'),
          :params_switch_solo_start_date => extract(response, 'switch_solo_start_date'),
          :params_terminal_id => extract(response, 'terminal_id'),
          :params_tx_ref_idx => extract(response, 'tx_ref_idx'),
          :params_tx_ref_num => extract(response, 'tx_ref_num'),
        }
      end
    end
  end
end
