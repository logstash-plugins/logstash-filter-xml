# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/filters/xml"

describe LogStash::Filters::Xml do

  # Common tests to validate behaviour of used xml parsing library
  RSpec.shared_examples "report _xmlparsefailure" do |config_string|

    describe "parsing standard xml (Deprecated checks)" do
      config(config_string)

      sample("xmldata" => '<foo key="value"/>') do
        insist { subject.get("tags") }.nil?
      end

      #From parse xml with array as a value
      sample("xmldata" => '<foo><key>value1</key><key>value2</key></foo>') do
        insist { subject.get("tags") }.nil?
      end

      #From parse xml with hash as a value
      sample("xmldata" => '<foo><key1><key2>value</key2></key1></foo>') do
        insist { subject.get("tags") }.nil?
      end

      # parse xml in single item array
      sample("xmldata" => ["<foo bar=\"baz\"/>"]) do
        insist { subject.get("tags") }.nil?
      end

      # fail in multi items array
      sample("xmldata" => ["<foo bar=\"baz\"/>", "jojoba"]) do
        insist { subject.get("tags") }.include?("_xmlparsefailure")
        insist { subject.get("data")} == nil
      end

      # fail in empty array
      sample("xmldata" => []) do
        insist { subject.get("tags") }.include?("_xmlparsefailure")
        insist { subject.get("data")} == nil
      end

      # fail for non string field
      sample("xmldata" => {"foo" => "bar"}) do
        insist { subject.get("tags") }.include?("_xmlparsefailure")
        insist { subject.get("data")} == nil
      end

      # fail for non string single item array
      sample("xmldata" => [{"foo" => "bar"}]) do
        insist { subject.get("tags") }.include?("_xmlparsefailure")
        insist { subject.get("data")} == nil
      end

      #From bad xml
      sample("xmldata" => '<foo /') do
        insist { subject.get("tags") }.include?("_xmlparsefailure")
      end
    end
  end

  context "ensure xml parsers consistent report of _xmlparsefailure" do

    #XMLSimple only, when no xpath
    context "XMLSimple validation" do
      config_string = <<-CONFIG
      filter {
        xml {
          source => "xmldata"
          target => "data"
        }
      }
      CONFIG
      include_examples "report _xmlparsefailure", config_string
    end

    #Nokogiri only when xpath exists and store_xml => false
    context "Nokogiri validation" do
      config_string = <<-CONFIG
      filter {
        xml {
          source => "xmldata"
          store_xml => false
          xpath => { "/" => nil }
        }
      }
      CONFIG
      include_examples "report _xmlparsefailure", config_string
    end
  end

  context "parse standard xml" do
    config <<-CONFIG
    filter {
      xml {
        source => "xmldata"
        target => "data"
      }
    }
    CONFIG

    sample("xmldata" => '<foo key="value"/>') do
      insist { subject.get("tags") }.nil?
      insist { subject.get("data") } == {"key" => "value"}
    end

    #From parse xml with array as a value
    sample("xmldata" => '<foo><key>value1</key><key>value2</key></foo>') do
      insist { subject.get("tags") }.nil?
      insist { subject.get("data") } == {"key" => ["value1", "value2"]}
    end

    #From parse xml with hash as a value
    sample("xmldata" => '<foo><key1><key2>value</key2></key1></foo>') do
      insist { subject.get("tags") }.nil?
      insist { subject.get("data") } == {"key1" => [{"key2" => ["value"]}]}
    end

    context "using formatting options" do
      context "forcing_array" do
        describe "enabled" do
          config <<-CONFIG
          filter {
            xml {
              source => "xmldata"
              target => "parseddata"
              force_array => true
            }
          }
          CONFIG

          # Single value
          sample("xmldata" => '<foo><bar>Content</bar></foo>') do
            insist { subject.get("parseddata") } == { "bar" => ["Content"] }
          end
        end

        describe "disabled" do
          config <<-CONFIG
          filter {
            xml {
              source => "xmldata"
              target => "parseddata"
              force_array => false
            }
          }
          CONFIG

          # Single value
          sample("xmldata" => '<foo><bar>Content</bar></foo>') do
            insist { subject.get("parseddata") } == { "bar" => "Content" }
          end
        end
      end

      context "suppress_empty" do
        describe "disabled" do
          config <<-CONFIG
          filter {
            xml {
              source => "xmldata"
              target => "data"
              suppress_empty => false
            }
          }
          CONFIG

          sample("xmldata" => '<foo><key>value1</key><key></key></foo>') do
            insist { subject.get("tags") }.nil?
            insist { subject.get("data") } == {"key" => ["value1", {}]}
          end
        end

        describe "enabled" do
          config <<-CONFIG
          filter {
            xml {
              source => "xmldata"
              target => "data"
              suppress_empty => true
            }
          }
          CONFIG

          sample("xmldata" => '<foo><key>value1</key><key></key></foo>') do
            insist { subject.get("tags") }.nil?
            insist { subject.get("data") } == {"key" => ["value1"]}
          end
        end
      end

      context "force_content" do
        describe "disabled" do
          config <<-CONFIG
          filter {
            xml {
              source => "xmldata"
              target => "data"
              force_array => false
              force_content => false
            }
          }
          CONFIG

          sample("xmldata" => '<opt><x>text1</x><y a="2">text2</y></opt>') do
            insist { subject.get("tags") }.nil?
            insist { subject.get("data") } ==  { 'x' => 'text1', 'y' => { 'a' => '2', 'content' => 'text2' } }
          end
        end
        describe "enabled" do
          config <<-CONFIG
          filter {
            xml {
              source => "xmldata"
              target => "data"
              force_array => false
              force_content => true
            }
          }
          CONFIG

          sample("xmldata" => '<opt><x>text1</x><y a="2">text2</y></opt>') do
            insist { subject.get("tags") }.nil?
            insist { subject.get("data") } ==  { 'x' => { 'content' => 'text1' }, 'y' => { 'a' => '2', 'content' => 'text2' } }
          end
        end
      end
    end
  end

  context "executing xpath query on the xml content and storing result in a field" do
    context "standard usage" do
      describe "parse xml and store values with xpath" do
        config <<-CONFIG
        filter {
          xml {
            source => "xmldata"
            store_xml => false
            xpath => [ "/foo/key/text()", "xpath_field" ]
          }
        }
        CONFIG

        # Single value
        sample("xmldata" => '<foo><key>value</key></foo>') do
          insist { subject.get("tags") }.nil?
          insist { subject.get("xpath_field") } == ["value"]
        end

        #Multiple values
        sample("xmldata" => '<foo><key>value1</key><key>value2</key></foo>') do
          insist { subject.get("tags") }.nil?
          insist { subject.get("xpath_field") } == ["value1","value2"]
        end
      end

      describe "parse correctly non ascii content with xpath" do
        config <<-CONFIG
        filter {
          xml {
            source => "xmldata"
            store_xml => false
            xpath => [ "/foo/key/text()", "xpath_field" ]
          }
        }
        CONFIG

        # Single value
        sample("xmldata" => '<foo><key>Français</key></foo>') do
          insist { subject.get("tags") }.nil?
          insist { subject.get("xpath_field")} == ["Français"]
        end
      end
    end

    context "xpath expression configuration" do

      describe "report syntax error" do
        config <<-CONFIG
        filter {
          xml {
            source => "xmldata"
            target => "data"
            xpath => [ "/foo/key/unknown-method()", "xpath_field" ]
          }
        }
        CONFIG

        sample("xmldata" => '<foo><key>Français</key></foo>') do
          insist { subject.get("tags") } == ["_xpathsyntaxfailure"]
        end
      end

      describe "retrieved from event field" do
        config <<-CONFIG
        filter {
          xml {
            source => "xmldata"
            target => "data"
            xpath => [ "%{xpath_query}", "xpath_field" ]
          }
        }
        CONFIG

        sample("xmldata" => '<foo><key>Français</key></foo>', "xpath_query" => "/foo/key/text()") do
          insist { subject.get("tags") }.nil?
          insist { subject.get("xpath_field")} == ["Français"]
        end
      end
    end

    context "namespace handling" do
      describe "parse including namespaces" do
        config <<-CONFIG
        filter {
          xml {
            source => "xmldata"
            xpath => [ "/foo/h:div", "xpath_field" ]
            remove_namespaces => false
            store_xml => false
          }
        }
        CONFIG

        # Single value
        sample("xmldata" => '<foo xmlns:h="http://www.w3.org/TR/html4/"><h:div>Content</h:div></foo>') do
          insist { subject.get("xpath_field") } == ["<h:div>Content</h:div>"]
        end
      end

      describe "parse including namespaces declarations on root" do
        config <<-CONFIG
        filter {
          xml {
            source => "xmldata"
            xpath => [ "/foo/h:div", "xpath_field" ]
            namespaces => {"h" => "http://www.w3.org/TR/html4/"}
            remove_namespaces => false
            store_xml => false
          }
        }
        CONFIG

        # Single value
        sample("xmldata" => '<foo xmlns:h="http://www.w3.org/TR/html4/"><h:div>Content</h:div></foo>') do
          insist { subject.get("xpath_field") } == ["<h:div>Content</h:div>"]
        end
      end

      describe "parse including namespaces declarations on child" do
        config <<-CONFIG
        filter {
          xml {
            source => "xmldata"
            xpath => [ "/foo/h:div", "xpath_field" ]
            namespaces => {"h" => "http://www.w3.org/TR/html4/"}
            remove_namespaces => false
            store_xml => false
          }
        }
        CONFIG

        # Single value
        sample("xmldata" => '<foo><h:div xmlns:h="http://www.w3.org/TR/html4/">Content</h:div></foo>') do
          insist { subject.get("xpath_field") } == ["<h:div xmlns:h=\"http://www.w3.org/TR/html4/\">Content</h:div>"]
        end
      end

      describe "parse removing namespaces" do
        config <<-CONFIG
        filter {
          xml {
            source => "xmldata"
            xpath => [ "/foo/div", "xpath_field" ]
            remove_namespaces => true
            store_xml => false
          }
        }
        CONFIG

        # Single value
        sample("xmldata" => '<foo xmlns:h="http://www.w3.org/TR/html4/"><h:div>Content</h:div></foo>') do
          insist { subject.get("xpath_field") } == ["<div>Content</div>"]
        end
      end
    end
  end

  context "plugin registration checks" do
    describe "ensure target is set when store_xml => true" do
      config <<-CONFIG
      filter {
        xml {
          xmldata => "message"
          store_xml => true
        }
      }
      CONFIG

      sample("xmldata" => "<foo>random message</foo>") do
        insist { subject }.raises(LogStash::ConfigurationError)
      end
    end

    describe "ensure xpath is set when store_xml => false" do
      config <<-CONFIG
      filter {
        xml {
          source => "xmldata"
          store_xml => false
        }
      }
      CONFIG

      sample("xmldata" => "<foo>random message</foo>") do
        insist { subject }.raises(LogStash::ConfigurationError)
      end
    end
  end
end
