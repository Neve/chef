#
# Author:: Prajakta Purohit (<prajakta@opscode.com>)
# Copyright:: Copyright (c) 2011 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'

require 'chef/win32/registry'

describe 'Chef::Win32::Registry', :windows_only do

  before(:all) do
    #Create a registry item
    ::Win32::Registry::HKEY_CURRENT_USER.create "Software\\Root"
    ::Win32::Registry::HKEY_CURRENT_USER.create "Software\\Root\\Branch"
    ::Win32::Registry::HKEY_CURRENT_USER.create "Software\\Root\\Branch\\Flower"
    ::Win32::Registry::HKEY_CURRENT_USER.open('Software\\Root', Win32::Registry::KEY_ALL_ACCESS) do |reg|
      reg['RootType1', Win32::Registry::REG_SZ] = 'fibrous'
      reg.write('Roots', Win32::Registry::REG_MULTI_SZ, ["strong roots", "healthy tree"])
    end
    ::Win32::Registry::HKEY_CURRENT_USER.open('Software\\Root\\Branch', Win32::Registry::KEY_ALL_ACCESS) do |reg|
      reg['Strong', Win32::Registry::REG_SZ] = 'bird nest'
    end
    ::Win32::Registry::HKEY_CURRENT_USER.open('Software\\Root\\Branch\\Flower', Win32::Registry::KEY_ALL_ACCESS) do |reg|
      reg['Petals', Win32::Registry::REG_MULTI_SZ] = ["Pink", "Delicate"]
    end

    #Create the node with ohai data
    events = Chef::EventDispatch::Dispatcher.new
    node = Chef::Node.new
    ohai = Ohai::System.new
    ohai.all_plugins
    node.consume_external_attrs(ohai.data,{})
    run_context = Chef::RunContext.new(node, {}, events)

    #Create a registry object that has access ot the node previously created
    @registry = Chef::Win32::Registry.new(run_context)
  end

  #Delete what is left of the registry key-values previously created
  after(:all) do
    ::Win32::Registry::HKEY_CURRENT_USER.open("Software") do |reg|
      reg.delete_key("Root", true)
    end
  end

  # Operating system
  # it "succeeds if the operating system is windows" do
  # end

  # Server Versions
  # it "succeeds if server versiion is 2003R2, 2008, 2008R2, 2012" do
  # end
  # it "falis if the server versions are anything else" do
  # end

  # If hive_exists
  it "returns true if the hive exists" do
    hive = @registry.hive_exists?("HKCU\\Software\\Root")
    hive.should == true
  end
  it "returns false if the hive does not exist" do
    lambda {@registry.hive_exists?("LYRU\\Software\\Root")}.should raise_error(Chef::Exceptions::Win32RegHiveMissing)
  end
  #it "returns false if the system architecture says 32bit but system is 64bit" do
  #pending
  #end

  #  key_exists
  it "returns true if the key path exists" do
    exists = @registry.key_exists?("HKCU\\Software\\Root\\Branch\\Flower", "i386")
    exists.should == true
  end
  it "returns false if the key path does not exist" do
    exists = @registry.key_exists?("HKCU\\Software\\Branch\\Flower", "i386")
    exists.should == false
  end
  it "returns an error if the hive does not exist" do
    lambda {@registry.key_exists?("JKLM\\Software\\Branch\\Flower", "i386")}.should raise_error(Chef::Exceptions::Win32RegHiveMissing)
  end

  # get_values
  it "returns all values for a key if it exists" do
    values = @registry.get_values("HKCU\\Software\\Root", "i386")
    values.should be_an_instance_of Array
    values.should == [{:name=>"RootType1", :type=>1, :data=>"fibrous"},
                      {:name=>"Roots", :type=>7, :data=>["strong roots", "healthy tree"]}]
  end
  #  it "returns a nil if the key does not exist" do
  #    values = @registry.get_values("HKCU\\Software\\Branch\\Flower", "i386")
  #    values.should == nil
  #  end

  #  update_value
  it "updates a value if the key, value exist and type matches and value different" do
    updated = @registry.update_value("HKCU\\Software\\Root\\Branch\\Flower", {:name=>"Petals", :type=>:multi_string, :data=>["Yellow", "Changed Color"]}, "i386")
    ::Win32::Registry::HKEY_CURRENT_USER.open("Software\\Root\\Branch\\Flower", Win32::Registry::KEY_ALL_ACCESS) do |reg|
      reg.each do |name, type, data|
        if name == 'Petals'
          if data == ["Yellow", "Changed Color"]
            @exists=true
          else
            @exists=false
          end
        end
      end
    end
    updated.should == true && @exists.should == true
    end
    it "gives an error if key and value exists and type does not match" do
      lambda {@registry.update_value("HKCU\\Software\\Root\\Branch\\Flower", {:name=>"Petals", :type=>:string, :data=>"Yellow"}, "i386")}.should raise_error(Chef::Exceptions::Win32RegTypesMismatch)
    end
    it "gives an error if key exists and value does not" do
      lambda {@registry.update_value("HKCU\\Software\\Root\\Branch\\Flower", {:name=>"Stamen", :type=>:multi_string, :data=>["Yellow", "Changed Color"]}, "i386")}.should raise_error(Chef::Exceptions::Win32RegValueMissing)
    end
    it "does nothing if all parameters are same" do
      updated = @registry.update_value("HKCU\\Software\\Root\\Branch\\Flower", {:name=>"Petals", :type=>:multi_string, :data=>["Yellow", "Changed Color"]}, "i386")
      updated.should == "no_action"
    end
    it "gives an error if the key does not exist" do
      lambda {@registry.update_value("HKCU\\Software\\Branch\\Flower", {:name=>"Petals", :type=>:multi_string, :data=>["Yellow", "Changed Color"]}, "i386")}.should raise_error(Chef::Exceptions::Win32RegKeyMissing)
    end

    #  create_value
    it "creates a value if it does not exist" do
      creates = @registry.create_value("HKCU\\Software\\Root\\Branch\\Flower", {:name=>"Buds", :type=>:string, :data=>"Closed"}, "i386")
      ::Win32::Registry::HKEY_CURRENT_USER.open("Software\\Root\\Branch\\Flower", Win32::Registry::KEY_ALL_ACCESS) do |reg|
        reg.each do |name, type, data|
          if name == "Buds" && type == 1 && data == "Closed"
            @exists=true
          else
            @exists=false
          end
        end
      end
    end
    it "throws an exception if the value exists" do
      lambda {@registry.create_value("HKCU\\Software\\Root\\Branch\\Flower", {:name=>"Buds", :type=>:string, :data=>"Closed"}, "i386")}.should raise_error(Chef::Exceptions::Win32RegValueExists)
      ::Win32::Registry::HKEY_CURRENT_USER.open("Software\\Root\\Branch\\Flower", Win32::Registry::KEY_ALL_ACCESS) do |reg|
        reg.each do |name, type, data|
          if name == "Buds" && type == 1 && data == "Closed"
            @exists=true
          else
            @exists=false
          end
        end
      end
      @exists.should == true
      #test with timestamp?
    end

    #  create_key
    it "gives an error if the path has missing keys but recursive set to false" do
      created = @registry.create_key("HKCU\\Software\\Root\\Trunk\\Peck\\Woodpecker", {:name=>"Peter", :type=>:string, :data=>"Little"}, "i386", false)
      ::Win32::Registry::HKEY_CURRENT_USER.open("Software\\Root", Win32::Registry::KEY_ALL_ACCESS) do |reg|
        reg.each_key do |key_name|
          if key_name == "Trunk"
            @exists=true
            break
          else
            @exists=false
          end
        end
      end
      created.should == false && @exists.should == false
    end
    it "creates the key_path if the keys were missing but recursive was set to true" do
      @registry.create_key("HKCU\\Software\\Root\\Trunk\\Peck\\Woodpecker", {:name=>"Peter", :type=>:string, :data=>"Little"}, "i386", true)
      ::Win32::Registry::HKEY_CURRENT_USER.open("Software\\Root\\Trunk\\Peck\\Woodpecker", Win32::Registry::KEY_ALL_ACCESS) do |reg|
        reg.each do|name, type, data|
          if name == "Peter" && type == 1 && data == "Little"
            @exists=true
          else
            @exists=false
          end
        end
      end
      @exists.should == true
    end
    it "gives an error if the architecture is wrong" do
      #pending
    end

    #  create_if_missing
    it "does not update a key if it exists" do
      @registry.create_key("HKCU\\Software\\Root\\Trunk\\Peck\\Woodpecker", {:name=>"Peter", :type=>:string, :data=>"Tiny"}, "i386", true)
      ::Win32::Registry::HKEY_CURRENT_USER.open("Software\\Root\\Trunk\\Peck\\Woodpecker", Win32::Registry::KEY_ALL_ACCESS) do |reg|
        reg.each do |name, type, data|
          if name == "Peter" && type == 1 && data == "Little"
            @exists=true
          elsif name == "Peter" && type == 1 && data == "Tiny"
            @exists=false
          end
        end
      end
      @exists.should == true
    end

    it "makes no changes to value if it exists and type matches" do
    end

    #  delete_values
    it "deletes values if the value exists" do
      @registry.delete_value("HKCU\\Software\\Root\\Trunk\\Peck\\Woodpecker", {:name=>"Peter", :type=>:string, :data=>"Tiny"}, "i386")
      exists = false
      ::Win32::Registry::HKEY_CURRENT_USER.open("Software\\Root\\Trunk\\Peck\\Woodpecker", Win32::Registry::KEY_ALL_ACCESS) do |reg|
        reg.each do |name, type, data|
          if name == "Peter" && type == 1 && data == "Little"
            exists=true
            break
          else
            exists=false
          end
        end
      end
      exists.should == false
    end
    #it "does nothing if value does not exist" do
    #pending
    #end

    #  delete_key
    #  it gives an error if the hive does not exist
    it "deletes a key if it has no subkeys" do
      #  create a key to be deleted in a before block
      @registry.delete_key("HKCU\\Software\\Root\\Branch\\Flower", {:name=>"Buds", :type=>:string, :data=>"Closed"}, "i386", false)
      exists = false
      ::Win32::Registry::HKEY_CURRENT_USER.open("Software\\Root\\Branch", Win32::Registry::KEY_ALL_ACCESS) do |reg|
        reg.each_key do |name|
          if name == "Flower"
            exists=true
            break
          else
            exists=false
          end
        end
      end
      exists.should == false
    end
    it "gives an error if key to delete has subkeys and recursive is false" do
      @registry.delete_key("HKCU\\Software\\Root\\Trunk", {:name=>"Strong", :type=>:string, :data=>"bird nest"}, "i386", false)
      exists = true
      ::Win32::Registry::HKEY_CURRENT_USER.open("Software\\Root", Win32::Registry::KEY_ALL_ACCESS) do |reg|
        reg.each_key do |name|
          if name == "Trunk"
            exists=true
            break
          else
            exists=false
          end
        end
      end
      exists.should == true
    end
    it "deletes a key if it has subkeys and recursive true" do
      @registry.delete_key("HKCU\\Software\\Root\\Trunk", {:name=>"Strong", :type=>:string, :data=>"bird nest"}, "i386", true)
      exists = true
      ::Win32::Registry::HKEY_CURRENT_USER.open("Software\\Root", Win32::Registry::KEY_ALL_ACCESS) do |reg|
        reg.each_key do |name|
          if name == "Trunk"
            exists=true
            break
          else
            exists=false
          end
        end
      end
      exists.should == false
    end
      it "does nothing if the key does not exist" do
        @registry.delete_key("HKCU\\Software\\Root\\Trunk", {:name=>"Strong", :type=>:string, :data=>"bird nest"}, "i386", true)
        exists = true
        ::Win32::Registry::HKEY_CURRENT_USER.open("Software\\Root", Win32::Registry::KEY_ALL_ACCESS) do |reg|
          reg.each_key do |name|
            if name == "Trunk"
              exists=true
              break
            else
              exists=false
            end
          end
        end
        exists.should == false
      end

    # has_subkeys
    # it "would give an exception if the hive was missing" do
    # end
    # it "would give and exception if the key was missing" do
    # end
    it "returns true if the key has subkeys" do
      subkeys = @registry.has_subkeys?("HKCU\\Software\\Root", "i386")
      exists = false
      ::Win32::Registry::HKEY_CURRENT_USER.open("Software\\Root", Win32::Registry::KEY_ALL_ACCESS) do |reg|
        reg.each_key{|name| exists=true}
      end
      subkeys.should == true
    end

    #  get_subkeys
    #  tests for keys or hive missing
    it "returns the array of subkeys for a given key" do
      subkeys = @registry.get_subkeys("HKCU\\Software\\Root", "i386")
      reg_subkeys = []
      ::Win32::Registry::HKEY_CURRENT_USER.open("Software\\Root", Win32::Registry::KEY_ALL_ACCESS) do |reg|
        reg.each_key{|name| reg_subkeys << name}
      end
      reg_subkeys.should == subkeys
    end

    #  describe "If the architecture is correct" do
    #    before(:all) do
    #      #how to preserve the original ohai and reapply later ?
    #      ohai_data = {:kernel => {:machine => "i386"}}
    #      ohai_data.stub!(:all_plugins).and_return(true)
    #      ohai_data.stub!(:data).and_return(ohai_data)
    #      Ohai::System.stub!(:new).and_return(ohai_data)
    #      node = Chef::Node.new
    #      node.consume_external_attrs(ohai_data, {})
    #      events = Chef::EventDispatch::Dispatcher.new
    #      run_context = Chef::RunContext.new(node, {}, events)
    #      @reg = Chef::Win32::Registry.new(run_context)
    #    end
    #    it "returns false if architecture is specified as 64bit but CCR on 32bit" do
    #      arch = @registry.architecture_correct("x86_64")
    #      arch.should == false
    #    end
    #    it "returns true if architecture specified and architecture of the CCR box matches" do
    #    end
    #    it "returns true is architecture is specified as 32bit but CCR on 64 bit" do
    #    end
    #    #key_exists
    #    #it "returns an error if the architecture is wrong" do
    #  #    lambda {@registry.key_exists?("HKCU\\Software\\Branch\\Flower", "i386")}.should raise_error(Chef::Exceptions::Win32RegArchitectureIncorrect)
    #     #end
    #    #
    #    #create_key
    #    #create_value
    #    #update_value
    #    #get_value
    #    #delete_Value
    #    #delete_key
    #    #has_subkey
    #    #get_subkey
    #    #hive_exists
    #  end

  end