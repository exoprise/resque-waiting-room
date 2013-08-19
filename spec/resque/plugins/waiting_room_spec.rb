require File.join(File.dirname(__FILE__) + '/../../spec_helper')

getp = -> { Resque.mongo["waitingroom_holding"].find({mykey: "DummyJob:remaining_performs"}).first["max_performs"].to_i }
describe Resque::Plugins::WaitingRoom do
  before(:each) do
    Resque.mongo.collections.each do |col|
      col.drop
    end
  end
  it "should validate the Resque linter" do
    Resque::Plugin.lint(Resque::Plugins::WaitingRoom)
  end

  context "can_be_performed" do
    it "should raise InvalidParams" do
      expect { DummyJob.can_be_performed('lol') }.to raise_error(Resque::Plugins::WaitingRoom::MissingParams)
    end

    it "should assign @period and @max_performs" do
      DummyJob.instance_variable_get("@period").should == 30
      DummyJob.instance_variable_get("@max_performs").should == 10
    end
  end

  context "waiting_room_redis_key" do
    it "should generate a redis key name based on the class" do
      DummyJob.waiting_room_redis_key.should == 'DummyJob:remaining_performs'
    end
  end

  context "custom matcher" do
    it "should match positive" do
      DummyJob.should be_only_performed(times: 10, period: 30)
    end
  end

  context "before_perform_waiting_room" do
    it "should call waiting_room_redis_key" do
      DummyJob.should_receive(:waiting_room_redis_key).and_return('DummyJob:remaining_performs')
      DummyJob.before_perform_waiting_room('args')
    end

    it "should call has_remaining_performs_key?" do
      DummyJob.should_receive(:has_remaining_performs_key?).and_return(false)
      DummyJob.before_perform_waiting_room('args')
    end

    it "should decrement performs" do
      DummyJob.before_perform_waiting_room('args')
      getp.call.should == 9
      DummyJob.before_perform_waiting_room('args')
      getp.call.should == 8
      DummyJob.before_perform_waiting_room('args')
      getp.call.should == 7
    end

    it "should prevent perform once there are no performs left" do
      9.times {DummyJob.before_perform_waiting_room('args')}
      getp.call.should == 1
      expect { DummyJob.before_perform_waiting_room('args') }.to raise_exception(Resque::Job::DontPerform)
    end
  end

  context "repush" do
    it "should call waiting_room_redis_key" do
      DummyJob.should_receive(:waiting_room_redis_key).and_return('DummyJob:remaining_performs')
      DummyJob.repush('args')
    end
  end

end
