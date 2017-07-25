shared_examples 'payment_flow_spec' do

  before(:each) do
    create_payment
  end

  after(:each) do
    @plugin.stop_plugin
  end

  it 'should be able to purchase' do
    Killbill::Orbital::OrbitalResponse.all.size.should == 1
    Killbill::Orbital::OrbitalTransaction.all.size.should == 0

    payment_response = @plugin.purchase_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :PURCHASE
    find_value_from_properties(payment_response.properties, 'processorResponse').should == '100'

    responses = Killbill::Orbital::OrbitalResponse.all
    responses.size.should == 2
    responses[0].api_call.should == 'add_payment_method'
    responses[0].message.should == 'Profile Request Processed'
    responses[1].api_call.should == 'purchase'
    responses[1].message.should == 'Approved'
    transactions = Killbill::Orbital::OrbitalTransaction.all
    transactions.size.should == 1
    transactions[0].api_call.should == 'purchase'
  end

  it 'should be able to charge and refund' do
    payment_response = @plugin.purchase_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :PURCHASE
    find_value_from_properties(payment_response.properties, 'processorResponse').should == '100'

    # Try a full refund
    refund_response = @plugin.refund_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[1].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    refund_response.status.should eq(:PROCESSED), refund_response.gateway_error
    refund_response.amount.should == @amount
    refund_response.transaction_type.should == :REFUND
  end

  it 'should be able to auth, capture and refund' do
    payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :AUTHORIZE
    find_value_from_properties(payment_response.properties, 'processorResponse').should == '100'

    # Try multiple partial captures
    partial_capture_amount = BigDecimal.new('10')
    1.upto(3) do |i|
      payment_response = @plugin.capture_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[i].id, @pm.kb_payment_method_id, partial_capture_amount, @currency, @properties, @call_context)
      payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
      payment_response.amount.should == partial_capture_amount
      payment_response.transaction_type.should == :CAPTURE
    end

    # Try a partial refund
    refund_response = @plugin.refund_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[4].id, @pm.kb_payment_method_id, partial_capture_amount, @currency, @properties, @call_context)
    refund_response.status.should eq(:PROCESSED), refund_response.gateway_error
    refund_response.amount.should == partial_capture_amount
    refund_response.transaction_type.should == :REFUND

    # Try to capture again
    payment_response = @plugin.capture_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[5].id, @pm.kb_payment_method_id, partial_capture_amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == partial_capture_amount
    payment_response.transaction_type.should == :CAPTURE
  end

  it 'should be able to auth and void' do
    payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :AUTHORIZE
    find_value_from_properties(payment_response.properties, 'processorResponse').should == '100'

    payment_response = @plugin.void_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[1].id, @pm.kb_payment_method_id, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.transaction_type.should == :VOID
  end

  it 'should be able to auth, partial capture and void' do
    payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :AUTHORIZE
    find_value_from_properties(payment_response.properties, 'processorResponse').should == '100'

    partial_capture_amount = BigDecimal.new('10')
    payment_response       = @plugin.capture_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[1].id, @pm.kb_payment_method_id, partial_capture_amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == partial_capture_amount
    payment_response.transaction_type.should == :CAPTURE

    payment_response = @plugin.void_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[2].id, @pm.kb_payment_method_id, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.transaction_type.should == :VOID
  end

  it 'should be able to credit' do
    payment_response = @plugin.credit_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :CREDIT
  end

  it 'should include host response code' do
    # Sending a specific amount of 530 will trigger the Do Not Honor error.
    payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, BigDecimal.new('530'), @currency, @properties, @call_context)
    payment_response.status.should eq(:ERROR), payment_response.gateway_error
    payment_response.transaction_type.should == :AUTHORIZE
    payment_response.amount.should be_nil
    find_value_from_properties(payment_response.properties, 'processorResponse').should == '530'
  end

  it 'should cancel UNDEFINED payments' do
    response = Killbill::Orbital::OrbitalResponse.create(:api_call => 'authorization',
                                                         :kb_account_id => @pm.kb_account_id,
                                                         :kb_payment_id => @kb_payment.id,
                                                         :kb_payment_transaction_id => @kb_payment.transactions[0].id,
                                                         :kb_tenant_id => @call_context.tenant_id,
                                                         :message => '{"exception_message":"Timeout","payment_plugin_status":"UNDEFINED"}',
                                                         :created_at => Time.now,
                                                         :updated_at => Time.now)

    # Set skip_gw=true, to avoid calling the report API
    transaction_info_plugins = @plugin.get_payment_info(@pm.kb_account_id, @kb_payment.id, [], @call_context)
    transaction_info_plugins.size.should == 1
    transaction_info_plugins.first.status.should eq(:UNDEFINED)

    cancel_threshold = Killbill::Plugin::Model::PluginProperty.new
    cancel_threshold.key = 'cancel_threshold'
    cancel_threshold.value = '0'
    properties_with_cancel_threshold = @properties.clone
    properties_with_cancel_threshold << cancel_threshold
    transaction_info_plugins = @plugin.get_payment_info(@pm.kb_account_id, @kb_payment.id, properties_with_cancel_threshold, @call_context)
    transaction_info_plugins.size.should == 1
    transaction_info_plugins.first.status.should eq(:CANCELED)

    # Verify the state is sticky
    transaction_info_plugins = @plugin.get_payment_info(@pm.kb_account_id, @kb_payment.id, @properties, @call_context)
    transaction_info_plugins.size.should == 1
    transaction_info_plugins.first.status.should eq(:CANCELED)
  end
end