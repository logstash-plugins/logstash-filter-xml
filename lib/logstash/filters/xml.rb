# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"

# XML filter. Takes a field that contains XML and expands it into
# an actual datastructure.
class LogStash::Filters::Xml < LogStash::Filters::Base

  config_name "xml"

  # Config for xml to hash is:
  # [source,ruby]
  #     source => source_field
  #
  # For example, if you have the whole XML document in your `message` field:
  # [source,ruby]
  #     filter {
  #       xml {
  #         source => "message"
  #       }
  #     }
  #
  # The above would parse the XML from the `message` field.
  config :source, :validate => :string, :required => true

  # Define target for placing the data
  #
  # For example if you want the data to be put in the `doc` field:
  # [source,ruby]
  #     filter {
  #       xml {
  #         target => "doc"
  #       }
  #     }
  #
  # XML in the value of the source field will be expanded into a
  # datastructure in the `target` field.
  # Note: if the `target` field already exists, it will be overridden.
  # Required if `store_xml` is true (which is the default).
  config :target, :validate => :string

  # xpath will additionally select string values (non-strings will be
  # converted to strings with Ruby's `to_s` function) from parsed XML
  # (using each source field defined using the method above) and place
  # those values in the destination fields. Configuration:
  # [source,ruby]
  # xpath => [ "xpath-syntax", "destination-field" ]
  #
  # Values returned by XPath parsing from `xpath-syntax` will be put in the
  # destination field. Multiple values returned will be pushed onto the
  # destination field as an array. As such, multiple matches across
  # multiple source fields will produce duplicate entries in the field.
  #
  # More on XPath: http://www.w3schools.com/xpath/
  #
  # The XPath functions are particularly powerful:
  # http://www.w3schools.com/xpath/xpath_functions.asp
  #
  config :xpath, :validate => :hash, :default => {}

  # By default the filter will store the whole parsed XML in the destination
  # field as described above. Setting this to false will prevent that.
  config :store_xml, :validate => :boolean, :default => true

  # By default only namespaces declarations on the root element are considered.
  # This allows to configure all namespace declarations to parse the XML document.
  #
  # Example:
  #
  # [source,ruby]
  # filter {
  #   xml {
  #     namespaces => {
  #       "xsl" => "http://www.w3.org/1999/XSL/Transform"
  #       "xhtml" => http://www.w3.org/1999/xhtml"
  #     }
  #   }
  # }
  #
  config :namespaces, :validate => :hash, :default => {}

  # Remove all namespaces from all nodes in the document.
  # Of course, if the document had nodes with the same names but different namespaces, they will now be ambiguous.
  config :remove_namespaces, :validate => :boolean, :default => false

  # By default empty xml elements result in an empty hash object.
  # This allows you to change this behavoir to ouput nothing if the element is empty.
  #
  # Example:
  # 
  # [source,ruby]
  # filter {
  #   xml {
  #     suppress_empty => true
  #   }
  # }
  #
  config :suppress_empty, :validate => :boolean
  
  XMLPARSEFAILURE_TAG = "_xmlparsefailure"

  def register
    require "nokogiri"
    require "xmlsimple"
  end

  def filter(event)
    matched = false

    @logger.debug? && @logger.debug("Running xml filter", :event => event)

    value = event[@source]
    return unless value

    if value.is_a?(Array)
      if value.length != 1
        event.tag(XMLPARSEFAILURE_TAG)
        @logger.warn("XML filter expects single item array", :source => @source, :value => value)
        return
      end

      value = value.first
    end

    unless value.is_a?(String)
      event.tag(XMLPARSEFAILURE_TAG)
      @logger.warn("XML filter expects a string but received a #{value.class}", :source => @source, :value => value)
      return
    end

    # Do nothing with an empty string.
    return if value.strip.empty?

    if @xpath
      begin
        doc = Nokogiri::XML(value, nil, value.encoding.to_s)
      rescue => e
        event.tag(XMLPARSEFAILURE_TAG)
        @logger.warn("Error parsing xml", :source => @source, :value => value, :exception => e, :backtrace => e.backtrace)
        return
      end
      doc.remove_namespaces! if @remove_namespaces

      @xpath.each do |xpath_src, xpath_dest|
        nodeset = @namespaces.empty? ? doc.xpath(xpath_src) : doc.xpath(xpath_src, @namespaces)

        # If asking xpath for a String, like "name(/*)", we get back a
        # String instead of a NodeSet.  We normalize that here.
        normalized_nodeset = nodeset.kind_of?(Nokogiri::XML::NodeSet) ? nodeset : [nodeset]

        normalized_nodeset.each do |value|
          # some XPath functions return empty arrays as string
          # TODO: (colin) the return statement here feels like a bug and should probably be a next ?
          return if value.is_a?(Array) && value.length == 0

          if value
            matched = true
            # TODO: (colin) this can probably be optimized to avoid the Event get/set at every loop iteration anf
            # the array should probably be created once, filled in the loop and set at after the loop but the return
            # statement above screws this strategy and is likely a bug anyway so I will not touch this until I can
            # deep a big deeper and verify there is a sufficient test harness to refactor this.
            data = event[xpath_dest] || []
            data << value.to_s
            event[xpath_dest] = data

            # do not use the following construct to set the event, we cannot assume anymore that the field values are in-place mutable
            # event[xpath_dest] ||= []
            # event[xpath_dest] << value.to_s
          end
        end
      end
    end

    if @store_xml
      begin
        xs = if @suppress_empty then 
          XmlSimple.new({ 'SuppressEmpty' => true }) 
        else
          XmlSimple.new() 
        end

        event[@target] = xs.xml_in(value)
        matched = true
      rescue => e
        event.tag(XMLPARSEFAILURE_TAG)
        @logger.warn("Error parsing xml with XmlSimple", :source => @source, :value => value, :exception => e, :backtrace => e.backtrace)
        return
      end
    end

    filter_matched(event) if matched
    @logger.debug? && @logger.debug("Event after xml filter", :event => event)
  end
end
