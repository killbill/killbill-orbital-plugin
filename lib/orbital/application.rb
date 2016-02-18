# -- encoding : utf-8 --

set :views, File.expand_path(File.dirname(__FILE__) + '/views')

include Killbill::Plugin::ActiveMerchant::Sinatra

configure do
  # Usage: rackup -Ilib -E test
  if development? or test?
    # Make sure the plugin is initialized
    plugin              = ::Killbill::Orbital::PaymentPlugin.new
    plugin.logger       = Logger.new(STDOUT)
    plugin.logger.level = Logger::INFO
    plugin.conf_dir     = File.dirname(File.dirname(__FILE__)) + '/..'
    plugin.start_plugin
  end
end

helpers do
  def plugin(session = {})
    ::Killbill::Orbital::PrivatePaymentPlugin.new(session)
  end
end

# curl -v http://127.0.0.1:9292/plugins/killbill-orbital/1.0/pms/1
get '/plugins/killbill-orbital/1.0/pms/:id', :provides => 'json' do
  if pm = ::Killbill::Orbital::OrbitalPaymentMethod.find_by_id(params[:id].to_i)
    pm.to_json
  else
    status 404
  end
end

# curl -v http://127.0.0.1:9292/plugins/killbill-orbital/1.0/transactions/1
get '/plugins/killbill-orbital/1.0/transactions/:id', :provides => 'json' do
  if transaction = ::Killbill::Orbital::OrbitalTransaction.find_by_id(params[:id].to_i)
    transaction.to_json
  else
    status 404
  end
end

# curl -v http://127.0.0.1:9292/plugins/killbill-orbital/1.0/responses/1
get '/plugins/killbill-orbital/1.0/responses/:id', :provides => 'json' do
  if transaction = ::Killbill::Orbital::OrbitalResponse.find_by_id(params[:id].to_i)
    transaction.to_json
  else
    status 404
  end
end
