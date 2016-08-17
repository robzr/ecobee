#!/usr/bin/env ruby

class TestSave
  require 'pp'

  def initialize
    @callbacks = {}
    Thread.new {
      loop do
        run_hooks
        sleep 5
      end
    }
  end   


  def register(type, *callback, &block)
    if block_given?
      @callbacks[type] = block
    else
      @callbacks[type] = callback[0] if callback.length > 0
    end
  end

  def run_hooks
    if rand(2) == 0
      puts "Running Load"
      token_data_load
    else
      puts "Running Save"
      token_data_save
    end
  end

  def token_data_load
    load_data = read_from_file if @save_files_enabled
    if @callbacks[:load].respond_to? :call
      load_data = @callbacks[:load].call(load_data)
    end
    process_load_data load_data if load_data
  end

  def token_data_save
    save_data = get_save_data
    if @callbacks[:save].respond_to? :call
      save_data = @callbacks[:save].call(save_data)
    end
    write_to_file save_data if @save_files_enabled
  end

end

# Load:
# - Reads file
# - callback filter
# - Processes to memory
#
# Save:
# - Processes from memory
# - callback filter
# - writes to file (read all file; overwrite only this section; write)

# access_token
# - is it expired?
#  - No: use existing
#  - Yes: re-load from file; doublecheck

# refresh - only run if token is expired or via init if @refresh_token supplied (?)
# - gets new token
# - loads to memory
# - runs save

# config elements:
# 
# app_key 
#
# (@status = :ready)
#   access_token
#   access_token_expire
#   refresh_token
#   scope (read-only)
#   token_type (read-only)
# (@status = :authorization_pending)
#   pin
#   code
#   code_expire

config[:pin]
config[:code]
config[:code_expire]
