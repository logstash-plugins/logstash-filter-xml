# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "insist"
require "logstash/filters/xml"

describe LogStash::Filters::Xml do

  describe "parse standard xml (Deprecated checks)" do
    config <<-CONFIG
    filter {
      xml {
        source => "raw"
        target => "data"
      }
    }
    CONFIG

    sample("raw" => '<foo key="value"/>') do
      insist { subject.get("tags") }.nil?
      insist { subject.get("data")} == {"key" => "value"}
    end

    #From parse xml with array as a value
    sample("raw" => '<foo><key>value1</key><key>value2</key></foo>') do
      insist { subject.get("tags") }.nil?
      insist { subject.get("data")} == {"key" => ["value1", "value2"]}
    end

    #From parse xml with hash as a value
    sample("raw" => '<foo><key1><key2>value</key2></key1></foo>') do
      insist { subject.get("tags") }.nil?
      insist { subject.get("data")} == {"key1" => [{"key2" => ["value"]}]}
    end

    # parse xml in single item array
    sample("raw" => ["<foo bar=\"baz\"/>"]) do
      insist { subject.get("tags") }.nil?
      insist { subject.get("data")} == {"bar" => "baz"}
    end

    # fail in multi items array
    sample("raw" => ["<foo bar=\"baz\"/>", "jojoba"]) do
      insist { subject.get("tags") }.include?("_xmlparsefailure")
      insist { subject.get("data")} == nil
    end

    # fail in empty array
    sample("raw" => []) do
      insist { subject.get("tags") }.include?("_xmlparsefailure")
      insist { subject.get("data")} == nil
    end

    # fail for non string field
    sample("raw" => {"foo" => "bar"}) do
      insist { subject.get("tags") }.include?("_xmlparsefailure")
      insist { subject.get("data")} == nil
    end

    # fail for non string single item array
    sample("raw" => [{"foo" => "bar"}]) do
      insist { subject.get("tags") }.include?("_xmlparsefailure")
      insist { subject.get("data")} == nil
    end

    #From bad xml
    sample("raw" => '<foo /') do
      insist { subject.get("tags") }.include?("_xmlparsefailure")
    end
  end

  describe "parse standard xml but do not store (Deprecated checks)" do
    config <<-CONFIG
    filter {
      xml {
        source => "raw"
        target => "data"
        store_xml => false
      }
    }
    CONFIG

    sample("raw" => '<foo key="value"/>') do
      insist { subject.get("tags") }.nil?
      insist { subject.get("data")} == nil
    end
  end

  describe "parse xml and store values with xpath (Deprecated checks)" do
    config <<-CONFIG
    filter {
      xml {
        source => "raw"
        target => "data"
        xpath => [ "/foo/key/text()", "xpath_field" ]
      }
    }
    CONFIG

    # Single value
    sample("raw" => '<foo><key>value</key></foo>') do
      insist { subject.get("tags") }.nil?
      insist { subject.get("xpath_field")} == ["value"]
    end

    #Multiple values
    sample("raw" => '<foo><key>value1</key><key>value2</key></foo>') do
      insist { subject.get("tags") }.nil?
      insist { subject.get("xpath_field")} == ["value1","value2"]
    end
  end

  ## New tests

  describe "parse standard xml" do
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

    #From bad xml
    sample("xmldata" => '<foo /') do
      insist { subject.get("tags") }.include?("_xmlparsefailure")
    end
  end

  describe "parse standard xml but do not store" do
    config <<-CONFIG
    filter {
      xml {
        source => "xmldata"
        target => "data"
        store_xml => false
      }
    }
    CONFIG

    sample("xmldata" => '<foo key="value"/>') do
      insist { subject.get("tags") }.nil?
      insist { subject.get("data")} == nil
    end
  end

  describe "parse xml and store values with xpath" do
    config <<-CONFIG
    filter {
      xml {
        source => "xmldata"
        target => "data"
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
        target => "data"
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


  describe "parse with forcing array (Default)" do
    config <<-CONFIG
    filter {
      xml {
        source => "xmldata"
        target => "parseddata"
      }
    }
    CONFIG

    # Single value
    sample("xmldata" => '<foo><bar>Content</bar></foo>') do
      insist { subject.get("parseddata") } == { "bar" => ["Content"] }
    end
  end

  describe "parse disabling forcing array" do
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

  describe "parse disabling forcing with nested elements" do
    config <<-CONFIG
    filter {
      xml {
        source => "xmldata"
        store_xml => "false"
        force_array => "false"
        xpath => [
          "/element/field1/text()", "field1"
        ]
      }
    }
    CONFIG

    # Single value
    sample("xmldata" => '<element><field1>bbb</field1><field2>789</field2><field3>e3f<field3></element>') do
      insist { subject.get("field1") } == "bbb"
    end
  end

  context "Using suppress_empty option" do
    describe "suppress_empty => false" do
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

    describe "suppress_empty => true" do
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

  context "Using force content option" do
    describe "force_content => false" do
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
    describe "force_content => true" do
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
    describe "does not set empty array event on failed xpath" do
      config <<-CONFIG
      filter {
        xml {
          source => "xmldata"
          target => "data"
          xpath => [ "//foo/text()","xpath_field" ]
        }
      }
      CONFIG

      sample("raw" => '<foobar></foobar>') do
        insist { subject.get("tags") }.nil?
        insist { subject.get("xpath_field")}.nil?
      end
    end
  end

  describe "parsing invalid xml" do
    subject { described_class.new(options) }
    let(:options) { ({ 'source' => 'xmldata', 'store_xml' => false }) }
    let(:xmldata) { "<xml> <sample attr='foo' attr=\"bar\"> <invalid> </sample> </xml>" }
    let(:event) { LogStash::Event.new(data) }
    let(:data) { { "xmldata" => xmldata } }

    before { subject.register }
    after { subject.close }

    it 'does not fail (by default)' do
      subject.filter(event)
      expect( event.get("tags") ).to be nil
    end

    context 'strict option' do
      let(:options) { super.merge({ 'parse_options' => 'strict' }) }

      it 'does fail parsing' do
        subject.filter(event)
        expect( event.get("tags") ).to_not be nil
        expect( event.get("tags") ).to include '_xmlparsefailure'
      end
    end
  end


  describe 'when an exception is thrown in XML#filter' do
    let(:logger_stub) { double('Logger').as_null_object }
    before(:each) do
      allow_any_instance_of(described_class).to receive(:logger).and_return(logger_stub)
    end

    subject(:xml_filter_plugin) { described_class.new(options).tap(&:register) }
    let(:options) { ({ 'source' => 'xmldata', 'store_xml' => true, 'target' => 'decoded' }) }
    let(:xmldata) { '<xml><sample attr="foo"></sample></xml>' }
    let(:event) { LogStash::Event.new(data) }
    let(:data) { { "xmldata" => xmldata } }

    after { xml_filter_plugin.close }

    # In order to test how we handle and propagate exceptions, we inject an
    # intentional failure when `filter_matched` is called, and parse an XML
    # that would not otherwise fail.
    before(:each) do
      expect(xml_filter_plugin).to receive(:filter_matched) { |_| fail('intentional') }
    end

    it 'does not propagate the exception' do
      expect{ xml_filter_plugin.filter(event) }.to_not raise_error
    end

    it 'emits the event with an error tag' do
      xml_filter_plugin.filter(event)

      expect(event.get("tags")).to_not be nil
      expect(event.get('tags')).to include '_xmlparsefailure'
    end

    it 'logs a helpful message' do
      xml_filter_plugin.filter(event)

      expect(logger_stub).to have_received(:warn) do |message, metadata|
        expect(message).to include('XML Parse Error')
        expect(metadata).to include(:value)
        expect(metadata).to include(:source)
      end
    end
  end

  describe "parse_options" do
    subject { described_class.new(options) }
    let(:options) { ({ 'source' => 'xmldata', 'store_xml' => false, 'parse_options' => parse_options }) }

    context 'strict (supported option)' do
      let(:parse_options) { 'strict' }

      it 'registers filter' do
        subject.register
        expect( subject.send(:xml_parse_options) ).
            to eql Nokogiri::XML::ParseOptions::STRICT
      end
    end

    context 'valid' do
      let(:parse_options) { 'no_error,NOWARNING' }

      it 'registers filter' do
        subject.register
        expect( subject.send(:xml_parse_options) ).
            to eql Nokogiri::XML::ParseOptions::NOERROR | Nokogiri::XML::ParseOptions::NOWARNING
      end
    end

    context 'invalid' do
      let(:parse_options) { 'strict,invalid0' }

      it 'fails to register' do
        expect { subject.register }.to raise_error(LogStash::ConfigurationError, 'unsupported parse option: "invalid0"')
      end
    end
  end
end
