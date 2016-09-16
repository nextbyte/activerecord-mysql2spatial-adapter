module ActiveRecord
  module Type
    class Spatial < Value # :nodoc:
      def type
        :spatial
      end

      def spatial?
        type == :spatial
      end

      def klass
        type == :spatial ? ::RGeo::Feature::Geometry : super
      end

      def set_geo_params(factory_settings, table_name, geometric_type, column)
        @factory_settings = factory_settings
        @table_name = table_name
        @geometric_type = geometric_type
        @column = column
      end

      def spatial_factory(srid = 4326)
        @spatial_factory ||=
          RGeo::ActiveRecord::SpatialFactoryStore.instance.factory(
            geo_type: 'point',
            has_m:    false,
            has_z:    false,
            sql_type: 'point',
            srid:     srid,
            sql_type: 'geography'
          )
      end

      private

      # convert WKT string into RGeo object
      def parse_wkt(string)
        wkt_parser(string).parse(string)
      rescue RGeo::Error::ParseError
        nil
      end

      def binary_string?(string)
        string[0] == "\x00" || string[0] == "\x01" || string[0, 4] =~ /[0-9a-fA-F]{4}/
      end

      def wkt_parser(string)
        if binary_string?(string)
          RGeo::WKRep::WKBParser.new(spatial_factory, support_ewkb: true, default_srid: @srid)
        else
          RGeo::WKRep::WKTParser.new(spatial_factory, support_ewkt: true, default_srid: @srid)
        end
      end

      def cast_value(value)
        case value
        when ::RGeo::Feature::Geometry
          factory = spatial_factory(value.srid)
          ::RGeo::Feature.cast(value, factory) rescue nil
        when ::String
          marker = value[4,1]
          if marker == "\x00" || marker == "\x01"
            factory = spatial_factory(value[0,4].unpack(marker == "\x01" ? 'V' : 'N').first)
            ::RGeo::WKRep::WKBParser.new(factory).parse(value[4..-1]) rescue nil
          elsif value[0,10] =~ /[0-9a-fA-F]{8}0[01]/
            srid = value[0,8].to_i(16)
            if value[9,1] == '1'
              srid = [srid].pack('V').unpack('N').first
            end
            factory = spatial_factory(srid)
            ::RGeo::WKRep::WKBParser.new(spatial_factory(srid)).parse(value[8..-1]) rescue nil
          else
            factory = spatial_factory
            ::RGeo::WKRep::WKTParser.new(factory, :support_ewkt => true).parse(value)# rescue nil
          end
        else
          nil
        end
      end
    end
  end
end
