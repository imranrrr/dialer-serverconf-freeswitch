#!/usr/bin/env ruby
# frozen_string_literal: false

require 'logger'
require 'active_record'
require 'drb'
require 'drb/acl'
require 'yaml'
require 'json'

settings = YAML.load_file("#{__dir__}/config.yml")
settings = settings['development']

D = true
ActiveRecord::Base.logger = ActiveSupport::Logger.new($stdout) if D

$logger = Logger.new("#{__dir__}/server.log", settings['logging'])

ActiveRecord::Base.establish_connection(
  adapter: 'mysql2',
  host: settings['mysql_host'],
  username: settings['mysql_user'],
  password: settings['mysql_password'],
  database: settings['mysql_db']
)


class Cdr < ActiveRecord::Base
end

list = File.readlines("#{__dir__}/acl.list", chomp: true)
acl = ACL.new(list, ACL::DENY_ALLOW)
p acl if D

DRb.install_acl(acl)

Thread.abort_on_exception = false

class Client
  def cdr_insert(data)
    $logger.debug "cdr_insert #{data}"
    pp "cdr_insert #{data}" if D
    ActiveRecord::Base.connection_pool.with_connection do
      cdr = Cdr.create(data).to_json || {}
    end
  rescue StandardError => e
    p data, e if D
    false
  end
end

DRb.start_service(settings['drubyserver'], Client.new, { safe_level: 1 })
p 'DRB started' if D

DRb.thread.join
