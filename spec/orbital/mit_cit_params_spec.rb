require 'spec_helper'

ActiveMerchant::Billing::Base.mode = :test

describe Killbill::Orbital::PaymentPlugin do

  include ::Killbill::Plugin::ActiveMerchant::RSpec

  before(:each) do
    @plugin = build_plugin(::Killbill::Orbital::PaymentPlugin, 'orbital')
    @plugin.start_plugin
    @call_context = build_call_context

    ::Killbill::Orbital::OrbitalPaymentMethod.delete_all
    ::Killbill::Orbital::OrbitalResponse.delete_all
    ::Killbill::Orbital::OrbitalTransaction.delete_all
  end

  after(:each) do
    @plugin.stop_plugin
  end

  context 'mit cit params spec' do
    before(:each) do
      @amount     = BigDecimal.new('100')
      @currency   = 'USD'
    end

    it 'should set correct mit cit params for the first transaction with credential_on_file true' do
      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'master' })
      @properties << build_property('mit_cit_type', 'CGEN')
      @properties << build_property('credential_on_file', true)
      validate_mit_cit_fields('CGEN', nil, 'Y');
    end

    it 'should set correct mit cit params for the first transaction with credential_on_file false' do
      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'master' })
      @properties << build_property('mit_cit_type', 'CGEN')
      @properties << build_property('credential_on_file', false)
      validate_mit_cit_fields('CGEN', nil, 'N');
    end

    it 'should not set mit cit params if the options are not available' do
      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'master' })
      validate_mit_cit_fields();
    end

    it 'should set correct mit cit params for the follow-up transaction' do
      @properties = build_pm_properties(nil, { :cc_number => '5454545454545454', :cc_type => 'master' })
      @properties << build_property('mit_cit_type', 'MSCU')
      @properties << build_property('credential_on_file', true)
      ref_mit_cit_trx_id = "test_mit_cit_trx_id"

      ::KillBill::Orbital::PaymentPlugin.any_instance.stub(:find_mit_ref_trx_id_if_needed) do
        ref_mit_cit_trx_id
      end

      validate_mit_cit_fields('MSCU', ref_mit_cit_trx_id, 'Y');
    end
  end

  def successful_authorize_response
    <<-XML
<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>A</MessageType><MerchantID>1111111</MerchantID><TerminalID>001</TerminalID><CardBrand>CC</CardBrand><AccountNum>XXXXXXXXXXXX5454</AccountNum><OrderID>5b257b31-1f84-44bc-b32</OrderID><TxRefNum>5834AA75E4466AEA59512165057C37DD810053C2</TxRefNum><TxRefIdx>0</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>1</ApprovalStatus><RespCode>00</RespCode><AVSRespCode>B </AVSRespCode><CVV2RespCode> </CVV2RespCode><AuthCode>tst424</AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Approved</StatusMsg><RespMsg></RespMsg><HostRespCode>100</HostRespCode><HostAVSRespCode>I3</HostAVSRespCode><HostCVV2RespCode>  </HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>152837</RespTime><PartialAuthOccurred></PartialAuthOccurred><RequestedAmount></RequestedAmount><RedeemedAmount></RedeemedAmount><RemainingBalance></RemainingBalance><CountryFraudFilterStatus></CountryFraudFilterStatus><IsoCountryCode></IsoCountryCode></NewOrderResp></Response>
    XML
  end

  def successful_purchase_response
    <<-XML
<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>AC</MessageType><MerchantID>1111111</MerchantID><TerminalID>001</TerminalID><CardBrand>CC</CardBrand><AccountNum>XXXXXXXXXXXX5454</AccountNum><OrderID>88132d30-f4f7-4028-949</OrderID><TxRefNum>5834EAC9C7A53FEB600A479629FB6C6427A2532C</TxRefNum><TxRefIdx>1</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>1</ApprovalStatus><RespCode>00</RespCode><AVSRespCode>3 </AVSRespCode><CVV2RespCode>I</CVV2RespCode><AuthCode>tst703</AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Approved</StatusMsg><RespMsg></RespMsg><HostRespCode>100</HostRespCode><HostAVSRespCode>  </HostAVSRespCode><HostCVV2RespCode>I</HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>200306</RespTime><PartialAuthOccurred></PartialAuthOccurred><RequestedAmount></RequestedAmount><RedeemedAmount></RedeemedAmount><RemainingBalance></RemainingBalance><CountryFraudFilterStatus></CountryFraudFilterStatus><IsoCountryCode></IsoCountryCode></NewOrderResp></Response>    XML
    XML
  end

  def validate_mit_cit_fields(mit_cit_flag = nil, mit_ref_trx_id = nil, credential_on_file = nil)
    ::ActiveMerchant::Billing::OrbitalGateway.any_instance.stub(:ssl_post) do |host, request_body|
      if mit_cit_flag.nil?
        request_body.should_not match('<MITMsgType>')
      else
        request_body.should match("<MITMsgType>#{mit_cit_flag}</MITMsgType>")
      end

      if mit_ref_trx_id.nil?
        request_body.should_not match('<MITSubmittedTransactionId>')
      else
        request_body.should match("<MITSubmittedTransactionId>#{mit_ref_trx_id}</MITSubmittedTransactionId>")
      end

      if credential_on_file.nil?
        request_body.should_not match('<MITStoredCredentialInd>')
      else
        request_body.should match("<MITStoredCredentialInd>#{credential_on_file}</MITStoredCredentialInd>")
      end

      if request_body.include? '<MessageType>A</MessageType>'
        successful_authorize_response
      else
        successful_purchase_response
      end
    end

    authorize
    purchase
  end

  def authorize
    kb_payment_id, kb_transaction_id = create_payment
    payment_response = @plugin.authorize_payment(SecureRandom.uuid, kb_payment_id, kb_transaction_id, SecureRandom.uuid, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :AUTHORIZE
  end

  def purchase
    kb_payment_id, kb_transaction_id = create_payment
    payment_response = @plugin.purchase_payment(SecureRandom.uuid, kb_payment_id, kb_transaction_id, SecureRandom.uuid, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :PURCHASE
  end
end