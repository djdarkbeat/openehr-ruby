require 'nokogiri'

module OpenEHR
  module Parser
    class OPTParser < ::OpenEHR::Parser::Base
      TEMPLATE_LANGUAGE_CODE_PATH = '/template/language/code_string'
      TEMPLATE_LANGUAGE_TERM_ID_PATH = '/template/language/terminology_id/value'
      TEMPLATE_ID_PATH = '/template/template_id/value'
      CONCEPT_PATH = '/template/concept'
      DESC_ORIGINAL_AUTHOR_PATH = '/template/description/original_author'
      DESC_LIFECYCLE_STATE_PATH = '/template/description/lifecycle_state'
      DESC_DETAILS_LANGUAGE_TERM_ID_PATH = '/template/description/details/language/terminology_id/value'
      DESC_DETAILS_LANGUAGE_CODE_PATH = '/template/description/details/language/code_string'
      DESC_DETAILS_PURPOSE_PATH = '/template/description/details/purpose'
      DESC_DETAILS_KEYWORDS_PATH = '/template/description/details/keywords'
      DESC_DETAILS_USE_PATH = '/template/description/details/use'
      DESC_DETAILS_MISUSE_PATH = '/template/description/details/misuse'
      DESC_DETAILS_COPYRIGHT_PATH = '/template/description/details/copyright'
      DEFINITION_PATH = '/template/definition'
      OCCURRENCE_PATH = '/occurrences'
      
      def initialize(filename)
        super(filename)
      end

      def parse
        @opt = Nokogiri::XML::Document.parse(File.open(@filename))
        terminology_id = OpenEHR::RM::Support::Identification::TerminologyID.new(value: text_on_path(@opt,TEMPLATE_LANGUAGE_TERM_ID_PATH))
        language = OpenEHR::RM::DataTypes::Text::CodePhrase.new(code_string: text_on_path(@opt, TEMPLATE_LANGUAGE_CODE_PATH), terminology_id: terminology_id)
        OpenEHR::AM::Template::OperationalTemplate.new(concept: concept, language: language, description: description, template_id: template_id, definition: definition)
      end

      private

      def template_id
        OpenEHR::RM::Support::Identification::TemplateID.new(value: text_on_path(@opt, TEMPLATE_ID_PATH))
      end

      def concept
        text_on_path(@opt, CONCEPT_PATH)
      end

      def description
        original_author = text_on_path(@opt, DESC_ORIGINAL_AUTHOR_PATH)
        lifecycle_state = text_on_path(@opt, DESC_LIFECYCLE_STATE_PATH)
        OpenEHR::RM::Common::Resource::ResourceDescription.new(original_author: original_author, lifecycle_state: lifecycle_state, details: [description_details])
      end

      def description_details
        terminology_id = OpenEHR::RM::Support::Identification::TerminologyID.new(value: text_on_path(@opt, DESC_DETAILS_LANGUAGE_TERM_ID_PATH))
        language = OpenEHR::RM::DataTypes::Text::CodePhrase.new(code_string: text_on_path(@opt, DESC_DETAILS_LANGUAGE_CODE_PATH), terminology_id: terminology_id)
        purpose = text_on_path(@opt, DESC_DETAILS_PURPOSE_PATH)
        keywords = @opt.xpath(DESC_DETAILS_KEYWORDS_PATH).inject([]) {|a, i| a << i.text}
        use = empty_then_nil text_on_path(@opt, DESC_DETAILS_USE_PATH)
        misuse = empty_then_nil text_on_path(@opt, DESC_DETAILS_MISUSE_PATH)
        copyright = empty_then_nil text_on_path(@opt, DESC_DETAILS_COPYRIGHT_PATH)
        OpenEHR::RM::Common::Resource::ResourceDescriptionItem.new(language: language, purpose: purpose, keywords: keywords, use: use, misuse: misuse, copyright: copyright)
      end

      def definition
        root_rm_type = text_on_path(@opt, DEFINITION_PATH + '/rm_type_name')
        root_node_id = text_on_path(@opt, DEFINITION_PATH + '/node_id')
        root_occurrences = occurrences(@opt.xpath(DEFINITION_PATH + OCCURRENCE_PATH))
        root_archetype_id = OpenEHR::RM::Support::Identification::ArchetypeID.new(value: text_on_path(@opt, DEFINITION_PATH+'/archetype_id/value'))
        root_path = "/[#{root_archetype_id}]"
        node = Node.new(root_node_id, root_path)
        root_attributes = attributes(@opt.xpath(DEFINITION_PATH+'/attributes'), node)
        OpenEHR::AM::Archetype::ConstraintModel::CArchetypeRoot.new(rm_type_name: root_rm_type, node_id: node.id, path: node.path, occurrences: root_occurrences, archetype_id: root_archetype_id, attributes: root_attributes)
      end

      def children(children_xml, node)
        children_xml.map do |child|
          send child.attributes['type'].text.downcase, child, node
        end
      end

      def c_complex_object(xml, node)
        rm_type_name = xml.xpath('./rm_type_name').text
        node_id = xml.xpath('./node_id').text
        node.id = node_id unless node_id.empty?
        node.path += node_id
        OpenEHR::AM::Archetype::ConstraintModel::CComplexObject.new(rm_type_name: rm_type_name, node_id: node.id, path: node.path, occurrences: occurrences(xml.xpath('./occurrences')), attributes: attributes(xml.xpath('./xpath'), node))
      end

      def attributes(attributes_xml, node)
        attributes_xml.map do |attr|
          send attr.attributes['type'].text.downcase, attr, node
        end
      end

      def c_single_attribute(attr_xml, node)
        rm_attribute_name = attr_xml.at('rm_attribute_name').text
        existence = occurrences(attr_xml.at('existence'))
        node.path += "/#{rm_attribute_name}"
        OpenEHR::AM::Archetype::ConstraintModel::CSingleAttribute.new(rm_attribute_name: rm_attribute_name, existence: existence, path: node.path, children: children(attr_xml.xpath('./children'), node))
      end

      def c_multiple_attribute(attr_xml, node)

      end

      def occurrences(occurrence_xml)
        lower = occurrence_xml.xpath('lower').text.to_i
        upper = occurrence_xml.xpath('upper').text.to_i
        lower_unbounded = to_bool(occurrence_xml.xpath('lower_unbounded'))
        upper_unbounded = to_bool(occurrence_xml.xpath('upper_unbounded'))
        lower_included = to_bool(occurrence_xml.xpath('lower_included'))
        upper_included = to_bool(occurrence_xml.xpath('upper_included'))
        OpenEHR::AssumedLibraryTypes::Interval.new(lower: lower, upper: upper, lower_unbounded: lower_unbounded, upper_unbounded: upper_unbounded, lower_included: lower_included, upper_included: upper_included)
      end
      
      def empty_then_nil(val)
        if val.empty?
          return nil
        else
          return val
        end
      end

      def text_on_path(xml, path)
        xml.xpath(path).text
      end

      def to_bool(str)
        if str =~ /true/i
          return true
        elsif str =~ /false/i
          return false
        end
        return nil
      end
    end
  end
end

class Node
  attr_accessor :id, :path

  def initialize(id, path)
    @id, @path = id, path
  end
end
