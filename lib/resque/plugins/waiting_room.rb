module Resque
  module Plugins
    module WaitingRoom
      class MissingParams < RuntimeError; end

      def mongo_collection
        Resque.mongo["waitingroom_holding"]
      end

      def can_be_performed(params)
        raise MissingParams unless params.is_a?(Hash) && params.keys.sort == [:period, :times]

        @period ||= params[:period]
        @max_performs ||= params[:times].to_i
      end

      def waiting_room_redis_key
        [self.to_s, "remaining_performs"].compact.join(":")
      end

      def before_perform_waiting_room(*args)
        key = waiting_room_redis_key

        if has_remaining_performs_key?(key)
          obj = mongo_collection.find_and_modify({
            "query" => {"mykey" => key},
            "update" => {"$inc" => {"max_performs" => -1}}
          })
          #p obj
          performs_left = obj["max_performs"].to_i #Resque.redis.decrby(key, 1).to_i
          #p performs_left  
          if performs_left <= 1
            Resque.push 'waiting_room', class: self.to_s, args: args
            raise Resque::Job::DontPerform
          end
        end
      end

      def has_remaining_performs_key?(key)
        k = nil
        mongo_collection.find({mykey: key}).each do |obj|
          if obj["expire_at"].to_i <= Time.now.to_i || obj["max_performs"].to_i <= 0
            mongo_collection.remove(obj) 
          else
            k = obj
          end
        end
        if k
          return true
        else
          opts = {
            "mykey" => key, 
            "max_performs" => @max_performs - 1,
            "expire_at" => Time.now.to_i + @period.to_i
          }
          mongo_collection.insert(opts)
          return false
        end
      end

      def max_performs_by_key(key)
        mongo_collection.find({"mykey" => key}).first["max_performs"].to_i 
      rescue 
        nil
      end

      def repush(*args)
        key = waiting_room_redis_key
        value = max_performs_by_key(key)
        no_performs_left = value && value != "" && value.to_i <= 0
        Resque.push 'waiting_room', class: self.to_s, args: args if no_performs_left
        return no_performs_left
      end
    end
  end
end
