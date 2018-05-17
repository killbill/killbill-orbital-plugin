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

  it 'should be able to auth, partial force-captures and refund' do
    payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :AUTHORIZE
    find_value_from_properties(payment_response.properties, 'processorResponse').should == '100'
    initial_order_id = payment_response.second_payment_reference_id

    # Try multiple partial captures
    partial_capture_amount = BigDecimal.new('10')
    @properties << build_property('force_capture', true)
    1.upto(3) do |i|
      payment_response = @plugin.capture_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[i].id, @pm.kb_payment_method_id, partial_capture_amount, @currency, @properties, @call_context)
      payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
      payment_response.amount.should == partial_capture_amount
      payment_response.transaction_type.should == :PURCHASE
      payment_response.second_payment_reference_id = initial_order_id
    end

    # Try a partial refund
    refund_response = @plugin.refund_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[4].id, @pm.kb_payment_method_id, partial_capture_amount, @currency, @properties, @call_context)
    refund_response.status.should eq(:PROCESSED), refund_response.gateway_error
    refund_response.amount.should == partial_capture_amount
    refund_response.transaction_type.should == :REFUND
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

  it 'should not fix undefined payment without a matching record from Orbital' do
    properties = merge_extra_properties(@properties, [build_property('trace_number', '1'),
                                                      build_property('order_id', '123412'),
                                                      build_property('skip_gw', 'true')])
    @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, properties, @call_context)
    transition_last_response_to_UNDEFINED(1)

    fix_transaction(0, :UNDEFINED)
  end

  it 'should eventually transition UNDEFINED payment to CANCELLED' do
    properties = merge_extra_properties(@properties, [build_property('trace_number', '1'),
                                                      skip_gw_property])
    @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, properties, @call_context)
    transition_last_response_to_UNDEFINED(1)

    properties = [zero_janitor_delay_property, zero_cancel_delay_property]
    transaction_info_plugins = @plugin.get_payment_info(@pm.kb_account_id, @kb_payment.id, properties, @call_context)
    transaction_info_plugins.size.should == 1
    transaction_info_plugins.last.status.should eq(:CANCELED)
  end

  it 'should fix undefined payment' do
    @properties << build_property('trace_number', '1')
    payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    response, initial_auth = transition_last_response_to_UNDEFINED(1)

    fix_transaction(0)

    # Compare the state of the old and new response
    check_old_new_response(response, :AUTHORIZE, 0, initial_auth, payment_response.first_payment_reference_id)

    capture_properties = merge_extra_properties(@properties, [build_property(:force_capture, true), build_property(:trace_number, '2')])
    capture_response = @plugin.capture_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[1].id, @pm.kb_payment_method_id, @amount, @currency, capture_properties, @call_context)

    # Force a transition to :UNDEFINED
    response, initial_auth = transition_last_response_to_UNDEFINED(2)

    fix_transaction(1)

    # Compare the state of the old and new response
    check_old_new_response(response, :PURCHASE, 1, initial_auth, capture_response.first_payment_reference_id)
  end

  def transition_last_response_to_UNDEFINED(expected_nb_transactions)
    Killbill::Orbital::OrbitalTransaction.last.delete
    response = Killbill::Orbital::OrbitalResponse.last
    initial_auth = response.authorization
    response.update(:authorization => nil, :message => {:payment_plugin_status => 'UNDEFINED'}.to_json)

    properties_with_skip_gw = merge_extra_properties(@properties, [skip_gw_property])
    transaction_info_plugins = @plugin.get_payment_info(@pm.kb_account_id, @kb_payment.id, properties_with_skip_gw, @call_context)
    transaction_info_plugins.size.should == expected_nb_transactions
    transaction_info_plugins.last.status.should eq(:UNDEFINED)

    [response, initial_auth]
  end

  def fix_transaction(transaction_nb, expected_state=:PROCESSED)
    # Plugin delay hasn't been reached yet
    transaction_info_plugins = @plugin.get_payment_info(@pm.kb_account_id, @kb_payment.id, @properties, @call_context)
    transaction_info_plugins.size.should == transaction_nb + 1
    transaction_info_plugins.last.status.should eq(:UNDEFINED)

    # Fix it
    properties_with_janitor_delay = merge_extra_properties(@properties, [zero_janitor_delay_property])
    transaction_info_plugins = @plugin.get_payment_info(@pm.kb_account_id, @kb_payment.id, properties_with_janitor_delay, @call_context)
    transaction_info_plugins.size.should == transaction_nb + 1
    transaction_info_plugins.last.status.should eq(expected_state)

    # Set skip_gw=true, to check the local state
    properties_with_skip_gw = merge_extra_properties(@properties, [skip_gw_property])
    transaction_info_plugins = @plugin.get_payment_info(@pm.kb_account_id, @kb_payment.id, properties_with_skip_gw, @call_context)
    transaction_info_plugins.size.should == transaction_nb + 1
    transaction_info_plugins.last.status.should eq(expected_state)
  end

  def merge_extra_properties(properties, extra_properties)
    new_properties = properties.clone
    extra_properties.each do |p|
      new_properties << p
    end
    new_properties
  end

  def check_old_new_response(response, transaction_type, transaction_nb, initial_auth, request_id)
    new_response = Killbill::Orbital::OrbitalResponse.last
    new_response.id.should == response.id
    new_response.api_call.should == transaction_type.to_s.downcase
    new_response.kb_tenant_id.should == @call_context.tenant_id
    new_response.kb_account_id.should == @pm.kb_account_id
    new_response.kb_payment_id.should == @kb_payment.id
    new_response.kb_payment_transaction_id.should == @kb_payment.transactions[transaction_nb].id
    new_response.transaction_type.should == transaction_type.to_s
    new_response.payment_processor_account_id.should == 'default'
    new_response.authorization.should == initial_auth
    new_response.test.should be_true
    new_response.params_order_id.should == response.params_order_id
    new_response.params_tx_ref_num.should == response.params_tx_ref_num
    new_response.params_trace_number.should == response.params_trace_number
    new_response.params_avs_resp_code.should == response.params_avs_resp_code unless response.params_avs_resp_code.nil?
    new_response.success.should be_true
  end

  def zero_janitor_delay_property
    build_property('janitor_delay_threshold', 0)
  end

  def zero_cancel_delay_property
    build_property('cancel_threshold', 0)
  end

  def skip_gw_property
    build_property('skip_gw', 'true')
  end

end