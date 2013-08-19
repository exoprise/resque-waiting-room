require 'resque'
require 'mongo'
#require 'embedded-mongo'
#require 'mock_redis'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'resque-waiting-room'))

RSpec.configure do |config|
  config.mock_framework = :rspec
end


$test_mongo = Mongo::MongoClient.new('localhost', 27017).db('test-room-db')
Resque.mongo = $test_mongo

# Require ruby files in support dir.
Dir[File.expand_path('spec/support/*.rb')].each { |file| require file }
