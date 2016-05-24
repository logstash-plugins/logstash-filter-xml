## 2.2.0
 - config: New configuration `suppress_empty`. By default the filter creates empty hash from empty xml elements (`suppress_empty => false`). 
   This can now be configured, `supress_empty => true` will not create event fields from empty xml elements.
 - config: New configuration `force_content`. By default the filter expands attributes differently from content in xml elements.
   This option allows you to force text content and attributes to always parse to a hash value.
 - config: Ensure that `target` is set when storing xml content in the event (`store_xml => true`)

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
