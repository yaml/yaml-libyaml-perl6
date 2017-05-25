use v6;
use NativeCall;

class LibYAML::Parser
{
    use LibYAML;
    has $.parser-raw;  # Just a place to hold the parser struct
    has LibYAML::event $.event = LibYAML::event.new;
    has $.encoding;
    has $.loader;
    has $.reader;

    method init()
    {
        $!parser-raw = buf8.allocate(yaml_parser_t_size);
        self.parser.init;
    }

    method delete()
    {
        self.parser.delete;
        $!parser-raw = Any;
    }

    method parser() { nativecast(LibYAML::parser-struct, $!parser-raw) }

    method parse-input() {
        my Str $str = $.reader.read;
        self.parse-string($str);
    }

    method parse-event() { self.parser.parse($!event) }

    method parse-string(Str $str, Str $encoding = 'utf-8')
    {
        my $buf = $str.encode($encoding);

        self.init;
        LEAVE self.delete;

        self.parser.set-input-string($buf);

        self.parse-stream;
    }

    method parse-file(Str $filename)
    {
        my $fh = LibYAML::FILEptr.open($filename, "rb");

        LEAVE .close with $fh;

        self.init;
        LEAVE self.delete;

        self.parser.set-input-file($fh);

        self.parse-stream;
    }

    method parse-stream()
    {
        self.parse-event;
        die unless $!event.type ~~ YAML_STREAM_START_EVENT;
        $!encoding = $!event.data.stream-start.encoding;
        $!event.delete;

        loop
        {
            self.parse-event;
            given $!event.type
            {
                when YAML_DOCUMENT_START_EVENT
                {
                    $.loader.document-start-event(%(), self);
                    self.parse-document
                }
                when YAML_STREAM_END_EVENT
                {
                    $!event.delete;
                    return;
                }
                default
                {
                    die;
                }
            }
        }
    }

    method parse-document()
    {
        $!event.delete;
        loop {
            self.parse-event;
            given $!event.type
            {
                when YAML_DOCUMENT_END_EVENT
                {
                    $.loader.document-end-event(%(), self);
                    $!event.delete;
                    return;
                }
                default
                {
                    self.parse-node;
                }
            }
        }
    }

    method parse-node()
    {
        given $!event.type
        {
            when YAML_ALIAS_EVENT          { self.parse-alias    }
            when YAML_SCALAR_EVENT         { self.parse-scalar   }
            when YAML_SEQUENCE_START_EVENT { self.parse-sequence }
            when YAML_MAPPING_START_EVENT  { self.parse-map      }
            default { die }
        }
    }

    method parse-alias()
    {
        LEAVE $!event.delete;
        my $name = nativecast(LibYAML::alias-data, $!event).anchor;
        $.loader.alias-event(%( alias => $name ), self);
    }

    method parse-scalar()
    {
        my $anchor = nativecast(LibYAML::sequence-start-data, $!event).anchor;
        my $d = nativecast(LibYAML::scalar-event-data, $!event);

        my $style = $d.style;

        my $scalar = buf8.new($d.value[0..^$d.length]).decode;

        $!event.delete;

        $.loader.scalar-event(
            %( value => $scalar, anchor => $anchor ), self
        );
        return $style != YAML_PLAIN_SCALAR_STYLE
            ?? $scalar
            !! do given $scalar
            {
                when ''|'null'                        { Any }

                when 'true'                           { True }

                when 'false'                          { False }

                when /^[<[-+]>? <[0..9]>+         |
                       0o <[0..7]>+               |
                       0x <[0..9a..fA..F]>+ ]$/       { .Int }

                when /^<[-+]>? [ 0 | <[0..9]>*]
                       '.' <[0..9]>+ $/               { .Rat }

                default                               { $_ }
            }
    }

    method parse-sequence()
    {
        my $anchor = nativecast(LibYAML::sequence-start-data, $!event).anchor;
        $.loader.sequence-start-event(%( anchor => $anchor ), self);
        $!event.delete;

        loop
        {
            self.parse-event;
            if $!event.type ~~ YAML_SEQUENCE_END_EVENT
            {
                $.loader.sequence-end-event(%(), self);
                $!event.delete;
                return;
            }
            self.parse-node;
        }
    }

    method parse-map()
    {
        my $anchor = nativecast(LibYAML::mapping-start-data, $!event).anchor;
        $.loader.mapping-start-event(%( anchor => $anchor ), self);
        $!event.delete;

        loop
        {
            self.parse-event;
            if $!event.type ~~ YAML_MAPPING_END_EVENT
            {
                $.loader.mapping-end-event(%(), self);
                $!event.delete;
                return;
            }
            my $key = self.parse-node;
            self.parse-event;
            my $value = self.parse-node;
        }
    }
}


