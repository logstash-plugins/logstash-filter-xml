## 4.1.0
 - bugfix: catch xpath-expression syntax error instead of impacting pipeline. Fix #19
 - bugfix: report xml parsing error when parsing only with xpath and store_xml => false (using Nokogiri internally). Fix #10
 - config: allow to create xpath-expression from event data using dynamic syntax
 - config: fail at startup if store_xml => false and no xpath config specified, as the filter would do nothing
 - internal: do not parse document with Nokogiri when xpath contains no expressions
 - internal: restructure tests using contexts

## 4.0.0
  - breaking,config: New configuration `suppress_empty`. Default to true change default behaviour of the plugin in favor of avoiding mapping conflicts when reaching elasticsearch
  - config: New configuration `force_content`. By default the filter expands attributes differently from content in xml elements.
    This option allows you to force text content and attributes to always parse to a hash value.
  - config: Ensure that `target` is set when storing xml content in the event (`store_xml => true`)

## 3.0.1
  - Republish all the gems under jruby.

## 3.0.0
  - Update the plugin to the version 2.0 of the plugin api, this change is required for Logstash 5.0 compatibility. See https://github.com/elastic/logstash/issues/5141

## 2.1.4
  - Added setting to disable forcing single values to be added in arrays. Ref: https://github.com/logstash-plugins/logstash-filter-xml/pull/28.

## 2.1.3
  - Depend on logstash-core-plugin-api instead of logstash-core, removing the need to mass update plugins on major releases of logstash

## 2.1.2
  - New dependency requirements for logstash-core for the 5.0 release

## 2.1.1
 - Refactored field references, code cleanups

## 2.1.0
 - Support for namespace declarations to use parsing the XML document

## 2.0.0
 - Plugins were updated to follow the new shutdown semantic, this mainly allows Logstash to instruct input plugins to terminate gracefully,
   instead of using Thread.raise on the plugins' threads. Ref: https://github.com/elastic/logstash/pull/3895
 - Dependency on logstash-core update to 2.0
