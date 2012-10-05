require 'sinatra/base'
require 'redis'
require 'snifter_collection'

ENV['REDIS_URL'] ||= 'redis://localhost:16379'

$redis = Redis.new
$snifters = SnifterCollection.new $redis

trap('CLD') do
  if pid = Process.wait(-1, Process::WNOHANG)
    puts "Snifter [#{pid}] stopped."
    $snifters.stopped pid
  end
end

class SnifterFrontend < Sinatra::Base
  set :root, File.expand_path('..', File.dirname(__FILE__))
  enable :method_override

  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
  end

  get '/' do
    erb :index
  end

  post '/snifter' do
    puts params.inspect
    snifter_id = params[:snifter_id]
    snifter_id = Time.now.to_i.to_s if snifter_id.nil? || snifter_id.empty?
    snifter = $snifters.add snifter_id, params[:snifter]
    snifter.start! if params[:start]
    redirect to('/')
  end

  delete '/:snifter_id' do
    $snifters.remove params[:snifter_id]
    redirect to('/')
  end

  get '/:snifter_id' do
    snifter = $snifters[params[:snifter_id]]
    erb :snifter, :locals => { :snifter => snifter }
  end

  post '/:snifter_id/start' do
    $snifters[params[:snifter_id]].start!
    redirect to(params[:return_to] || '/')
  end

  post '/:snifter_id/stop' do
    $snifters[params[:snifter_id]].stop!
    redirect to(params[:return_to] || '/')
  end

  get '/:snifter_id/:sess' do
    snifter = $snifters[params[:snifter_id]]
    req, res = snifter.session(params[:sess])
    erb :session, :locals => { :req => req, :res => res }, :layout => false
  end

  delete '/:snifter_id/sessions' do
    snifter = $snifters[params[:snifter_id]]
    snifter.clear!
    redirect to("/#{snifter.id}")
  end

  post '/:snifter_id/session' do
    snifter = $snifters[params[:snifter_id]]
    name = params[:session_name] || 'ls /svn'
    sessions = params[:sessions]
    snifter.save_group(name, sessions)
    redirect to("/#{snifter.id}")
  end

  #post '/:snifter_id/session' do
  #  @snifter = $snifters[params[:snifter_id]]
  #  @snifter.start_session params[:session]
  #  redirect to("/#{@snifter.id}")
  #end
  #
  #get '/:snifter_id/requests' do
  #  @snifter = $snifters[params[:snifter_id]]
  #  erb :all_requests
  #end
  #
  #get '/:snifter_id/request/:request_id' do
  #end
end
