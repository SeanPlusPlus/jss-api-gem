### Copyright 2014 Pixar
###  
###    Licensed under the Apache License, Version 2.0 (the "Apache License")
###    with the following modification; you may not use this file except in
###    compliance with the Apache License and the following modification to it:
###    Section 6. Trademarks. is deleted and replaced with:
###  
###    6. Trademarks. This License does not grant permission to use the trade
###       names, trademarks, service marks, or product names of the Licensor
###       and its affiliates, except as required to comply with Section 4(c) of
###       the License and to reproduce the content of the NOTICE file.
###  
###    You may obtain a copy of the Apache License at
###  
###        http://www.apache.org/licenses/LICENSE-2.0
###  
###    Unless required by applicable law or agreed to in writing, software
###    distributed under the Apache License with the above modification is
###    distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
###    KIND, either express or implied. See the Apache License for the specific
###    language governing permissions and limitations under the Apache License.
### 
###

###
module JSS



  #####################################
  ### Constants
  #####################################

  #####################################
  ### Module Variables
  #####################################

  #####################################
  ### Module Methods
  #####################################

  ####################################
  ### Classes
  #####################################


  ###
  ### The parent class of ExtensionAttribute objects in the JSS.
  ###
  ### The API extension attribute objects work with the definitions of extension
  ### attributes, not the resulting values stored in the JSS with the inventory
  ### reports.
  ###
  ### This superclass, however, uses the {AdvancedSearch} subclasses to provide
  ### access to the reported values in two ways:
  ### * A list of  target objects with a certain value for the ExtensionAttribute instance.
  ###   See the {#all_with_result} method for details
  ### * A list of the most recent value for this ExtensionAttribute in all targets in the JSS
  ###
  ### The {ComputerExtensionAttribute} subclass offers a {ComputerExtensionAttribute#history}
  ### method providing the history of values for the EA for one computer. This requires
  ### MySQL access to the JSS database since that history isn't available via the API.
  ###
  ### Subclasses of ExtensionAttribute must define these constants:
  ### * TARGET_CLASS - the {APIObject} subclass to which the extention attribute applies.
  ###   e.g. {JSS::Computer}
  ###
  ### * ALL_TARGETS_CRITERION - a {JSS::Criteriable::Criterion} instance that will be used in 
  ###   an {AdvancedSearch} to find all of members of the TARGET_CLASS
  ###
  ### @see JSS::APIObject
  ###
  class ExtensionAttribute < JSS::APIObject

    #####################################
    ### Mix-Ins
    #####################################
    include JSS::Creatable
    include JSS::Updatable

    #####################################
    ### Class Methods
    #####################################

    #####################################
    ### Class Constants
    #####################################

    ### What kinds of data can be created by EAs?
    ### Note, Dates must be in the format "YYYY-MM-DD hh:mm:ss"
    DATA_TYPES = ["String", "Date", "Integer"]
    DEFAULT_DATA_TYPE = "String"

    ### Where does the data come from?
    INPUT_TYPES = [ "Text Field", "Pop-up Menu", "script", "LDAP Attribute Mapping"]
    DEFAULT_INPUT_TYPE = "Text Field"

    ### These input types can be modified, the others cannot.
    EDITABLE_INPUT_TYPES = ["Text Field", "Pop-up Menu"]

    ### Where can it be displayed in the WebApp?
    ### subclasses can add to this list
    WEB_DISPLAY_CHOICES = [
      "General",
      "Operating System",
      "Hardware",
      "User and Location",
      "Purchasing",
      "Extension Attributes"
    ]
    DEFAULT_WEB_DISPLAY_CHOICE = "Extension Attributes"


    ######################
    ### Attributes
    ######################

    ### :id, :name, :in_jss, :need_to_update, and :rest_rsrc come from JSS::APIObject

    ### @return [String] description of the ext attrib
    attr_reader :description

    ### @return [String] the type of data created by the EA. Must be one of DATA_TYPES
    attr_reader :data_type

    ### @return [String]  where does this data come from? Must be one of the INPUT_TYPES.
    attr_reader :input_type

    ### @return [Array<String>] the choices available in the UI when the @input_type is "Pop-up Menu"
    attr_reader :popup_choices

    ### @return [String] In which part of the web UI does the data appear?
    attr_reader :web_display



    #####################################
    ### Constructor
    #####################################

    ###
    ### @see JSS::APIObject#initialize
    ###
    def initialize(args = {})

      super args

      ### @init_data now has the raw data
      ### so fill in our attributes or set defaults

      @description = @init_data[:description]
      @data_type = @init_data[:data_type] || DEFAULT_DATA_TYPE
      @web_display = @init_data[:inventory_display] || DEFAULT_WEB_DISPLAY_CHOICE

      
      if @init_data[:input_type]
        @input_type = @init_data[:input_type][:type] || DEFAULT_INPUT_TYPE
        @popup_choices = @init_data[:input_type][:popup_choices]
      else
        @input_type = DEFAULT_INPUT_TYPE
      end

      ### the name of the EA might have spaces and caps, which the will come to us as symbols with the spaces
      ### as underscores, like this.
      @symbolized_name = @name.gsub(' ','_').to_sym

    end # init

    #####################################
    ### Public Instance Methods
    #####################################

    ###
    ### @see JSS::Creatable#create
    ###
    def create
      if @input_type == "Pop-up Menu"
          raise MissingDataError, "No popup_choices set for Pop-up Menu input_type." unless @popup_choices.kind_of? Array and (not @popup_choices.empty?)
      end
      super
    end

    ###
    ### @see JSS::Updatable#update
    ###
    def update
      if @input_type == "Pop-up Menu"
          raise MissingDataError, "No popup_choices set for Pop-up Menu input_type." unless @popup_choices.kind_of? Array and (not @popup_choices.empty?)
      end
      super
    end
    
    
    ###
    ### @see JSS::APIObject#delete
    ###
    def delete
      orig_open_timeout = JSS::API.cnx.options[:open_timeout]
      orig_timeout = JSS::API.cnx.options[:timeout]
      JSS::API.timeout = orig_timeout + 1800
      JSS::API.open_timeout = orig_open_timeout + 1800
      begin
        super
      ensure
        JSS::API.timeout = orig_timeout
        JSS::API.open_timeout = orig_open_timeout
      end
    end
    
    ###
    ### Change the description of this EA
    ###
    ### @param new_val[String] the new value
    ###
    ### @return [void]
    ###
    def description= (new_val)
      return nil if @description == new_val
      @description = new_val
      @need_to_update = true
    end #  name=(newname)

    ###
    ### Change the data type of this EA
    ###
    ### @param new_val[String] the new value, which must be a member of DATA_TYPES
    ###
    ### @return [void]
    ###
    def data_type= (new_val)
      return nil if @data_type == new_val
      raise JSS::InvalidDataError, "data_type must be a string, one of: #{DATA_TYPES.join(", ")}" unless DATA_TYPES.include? new_val
      @data_type = new_val
      @need_to_update = true
    end #


    ###
    ### Change the inventory_display of this EA
    ###
    ### @param new_val[String] the new value, which must be a member of INVENTORY_DISPLAY_CHOICES
    ###
    ### @return [void]
    ###
    def web_display= (new_val)
      return nil if @web_display == new_val
      raise JSS::InvalidDataError, "inventory_display must be a string, one of: #{INVENTORY_DISPLAY_CHOICES.join(", ")}" unless WEB_DISPLAY_CHOICES.include? new_val
      @web_display = new_val
      @need_to_update = true
    end #


    ###
    ### Change the input type of this EA
    ###
    ### @param new_val[String] the new value, which must be a member of INPUT_TYPES
    ###
    ### @return [void]
    ###
    def input_type= (new_val)
      return nil if @input_type == new_val
      raise JSS::InvalidDataError, "input_type must be a string, one of: #{INPUT_TYPES.join(", ")}" unless INPUT_TYPES.include? new_val
      @input_type = new_val
      @popup_choices = nil if @input_type == "Text Field"
      @need_to_update = true
    end #

    ###
    ### Change the Popup Choices of this EA
    ### New value must be an Array, the items will be converted to Strings.
    ###
    ### This automatically sets input_type to "Pop-up Menu"
    ###
    ### Values are checked to ensure they match the @data_type
    ### Note, Dates must be in the format "YYYY-MM-DD hh:mm:ss"
    ###
    ### @param new_val[Array<#to_s>] the new values
    ###
    ### @return [void]
    ###
    def popup_choices= (new_val)
      return nil if @popup_choices == new_val
      raise JSS::InvalidDataError, "popup_choices must be an Array" unless new_val.kind_of?(Array)

      ### convert each one to a String,
      ### and check that it matches the @data_type
      new_val.map! do |v|
        v = v.to_s.strip
        case @data_type
          when "Date"
            raise JSS::InvalidDataError, "data_type is Date, but '#{v}' is not formatted 'YYYY-MM-DD hh:mm:ss'" unless v =~ /^\d{4}(-\d\d){2} (\d\d:){2}\d\d$/
          when "Integer"
            raise JSS::InvalidDataError, "data_type is Integer, but '#{v}' is not one" unless v =~ /^\d+$/
        end
        v
      end
      self.input_type = "Pop-up Menu"
      @popup_choices = new_val
      @need_to_update = true
    end #


    ###
    ### Get an Array of Hashes for all inventory objects
    ### with a desired result in their latest report for this EA.
    ###
    ### Each Hash is one inventory object (computer, mobile device, user), with these keys:
    ###   :id - the computer id
    ###   :name - the computer name
    ###   :value - the matching ext attr value for the objects latest report.
    ###
    ### This is done by creating a temprary {AdvancedSearch} for objects with matching
    ### values in the EA field, then getting the #search_results hash from it.
    ###
    ### The AdvancedSearch is then deleted.
    ###
    ### @param search_type[String] how are we comparing the stored value with the desired value.
    ### must be a member of JSS::Criterion::SEARCH_TYPES
    ###
    ### @param desired_value[String] the value to compare with the stored value to determine a match.
    ###
    ### @return [Array<Hash{:id=>Integer,:name=>String,:value=>String,Integer,Time}>] the items that match the result.
    ###
    def all_with_result(search_type, desired_value)
      raise JSS::NoSuchItemError, "EA Not In JSS! Use #create to create this #{self.class::RSRC_OBJECT_KEY}." unless @in_jss
      raise JSS::InvalidDataError, "Invalid search_type, see JSS::Criteriable::Criterion::SEARCH_TYPES" unless JSS::Criteriable::Criterion::SEARCH_TYPES.include? search_type.to_s
      begin

        search_class = self.class::TARGET_CLASS::SEARCH_CLASS
        acs = search_class.new :id => :new, :name => "JSSgem-EA-#{Time.now.to_jss_epoch}-result-search"
        acs.display_fields = [@name]
        crit_list = [JSS::Criteriable::Criterion.new(:and_or => "and", :name => @name, :search_type => search_type.to_s, :value => desired_value)]
        acs.criteria = JSS::Criteriable::Criteria.new crit_list

        acs.create :get_results

        results = []

        acs.search_results.each{ |i|
          value = case @data_type
            when "Date" then JSS.parse_datetime i[@symbolized_name]
            when "Integer" then i[@symbolized_name].to_i
            else i[@symbolized_name]
          end # case
          results << {:id => i[:id], :name => i[:name], :value => value}
        }

      ensure
        acs.delete
      end
      results
    end



    ###
    ### Return an Array of Hashes showing the most recent value
    ### for this EA on all inventory objects in the JSS.
    ###
    ### Each Hash is one inventory object (computer, mobile device, user), with these keys:
    ###   :id - the jss id
    ###   :name - the object name
    ###   :value - the most recent ext attr value for the object.
    ###
    ### This is done by creating a temporary {AdvancedSearch}
    ### for all objects, with the EA as a display field. The #search_result
    ### then contains the desired data.
    ###
    ### The AdvancedSearch is then deleted.
    ###
    ### @return [Array<Hash{:id=>Integer,:name=>String,:value=>String,Integer,Time}>]
    ###
    ### @see JSS::AdvancedSearch
    ###
    ### @see JSS::AdvancedComputerSearch
    ###
    ### @see JSS::AdvancedMobileDeviceSearch
    ###
    ### @see JSS::AdvancedUserSearch
    ###
    def latest_values
      raise JSS::NoSuchItemError, "EA Not In JSS! Use #create to create this #{self.class::RSRC_OBJECT_KEY}." unless @in_jss
      tmp_advsrch = "JSSgem-EA-#{Time.now.to_jss_epoch}-latest-search"
      
      begin
        search_class = self.class::TARGET_CLASS::SEARCH_CLASS
        acs = search_class.new :id => :new, :name => tmp_advsrch
        acs.display_fields = [@name]

        # search for 'Username like "" ' because all searchable object classes have a "Username" value
        #crit_list = [JSS::Criteriable::Criterion.new(:and_or => "and", :name => "Username", :search_type => "like", :value => '')]

        acs.criteria = JSS::Criteriable::Criteria.new [ self.class::ALL_TARGETS_CRITERION]
        acs.create :get_results

        results = []

        acs.search_results.each{ |i|
          value = case @data_type
            when "Date" then JSS.parse_datetime i[@symbolized_name]
            when "Integer" then i[@symbolized_name].to_i
            else i[@symbolized_name]
          end # case
          results << {:id => i[:id], :name => i[:name], :value => value}
        }

      ensure
        acs.delete
        self.class::TARGET_CLASS::SEARCH_CLASS.new(:name => tmp_advsrch).delete if self.class::TARGET_CLASS::SEARCH_CLASS.all_names(:refresh).include? tmp_advsrch
      end

      results

    end
    
    
    ### aliases
    
    alias desc description



    ######################
    ### Private Instance Methods
    #####################

    private

    ###
    ### Return a REXML object for this ext attr, with the current values.
    ### Subclasses should augment this in their rest_xml methods
    ### then return it .to_s, for saving or updating
    ###
    def rest_rexml
      ea = REXML::Element.new self.class::RSRC_OBJECT_KEY.to_s
      ea.add_element('name').text = @name
      ea.add_element('description').text = @description
      ea.add_element('data_type').text = @data_type
      ea.add_element('inventory_display').text = @web_display

      it = ea.add_element('input_type')
      it.add_element('type').text = @input_type
      if @input_type == "Pop-up Menu"
        pcs = it.add_element('popup_choices')
        @popup_choices.each{|pc| pcs.add_element('choice').text = pc}
      end
      return ea
    end # rest xml


  end # class ExtAttrib

end # module JSS

require "jss-api/api_object/extension_attribute/computer_extension_attribute"
require "jss-api/api_object/extension_attribute/mobile_device_extension_attribute"
require "jss-api/api_object/extension_attribute/user_extension_attribute"
