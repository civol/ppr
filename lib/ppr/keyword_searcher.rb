######################################################################
##              Map class for searching keywords in a text.         ##
######################################################################


class KeywordSearcher

    ## Creates a new keyword searcher, where words are between +seperators+
    #  regular expressions.
    def initialize(separator = "")
        # Checks and set the separator.
        @separator = Regexp.new(separator).to_s
        # Initialize the inner map.
        @map = {}
        # Initialize the list of keywords
        @keywords = []
        # Initialize the keyword extraction regular expression
        @keyword_extract = //
    end

    # Converts to an hash: actually return self.
    #
    # NOTE: for duck typing purpose.
    def to_h
        return self
    end

    ## Adds a +keyword+ to the searcher associated with an +object+.
    def []=(keyword,object)
        # Ensure the keyword is a valid string.
        keyword = keyword.to_str
        unless /^[A-Za-z_]\w*$/.match(keyword)
            raise "Invalid string for a keyword: #{keyword}." 
        end
        # Update the map.
        @map[keyword] = object
        # Get the keywords sorted in reverse order (used for building the
        # searching regular expressions).
        @keywords = @map.keys.sort!.reverse!
        # Update the searching regular expression.
        @keyword_extract = Regexp.new(@keywords.join("|"))
    end

    ## Get the object corresponding to +keyword+.
    def [](keyword)
        return @map[keyword.to_s]
    end

    ## Search a keyword inside a +text+ and return the corresponding object
    #  if found with the range in the string where it has been found.
    #
    #  If a keyword is in +skip+ it s ignored.
    #
    #  NOTE: the first found object is returned.
    def find(text,skip = [])
        # print "skip=#{skip} @keywords=#{@keywords}\n"
        # Compute the regular expression for finding the keywords.
        rexp = Regexp.new( (@keywords - skip).map! do |k|
            @separator + k + @separator
        end.join("|") )
        # print "find with @rexp=#{@rexp}\n"
        # Look for the first keyword.
        matched = rexp.match(text)
        # Isolate the keyword from the separators.
        # found = @keywords.match(matched.to_s)
        found = @keyword_extract.match(matched.to_s)
        if found then
            found = found.to_s
            # A keyword is found, adjust the range and 
            # return it with the corresponding object.
            range = matched.offset(0)
            range[0] += matched.to_s.index(found)
            range[1] = range[0] + found.size - 1
            return [ @map[found], range[0]..range[1] ]
        else
            # A keyword is not found.
            return nil
        end
    end

    ## Search each keyword inside a +text+ and apply the block on the
    #  corresponding objects if found with the range in the string where it
    #  has been found.
    #
    #  Returns an enumerator if no block is given.
    #
    #  NOTE: keywords included into a longer one are ignored.
    def each_in(text)
        return to_enum(:each_in,text) unless block_given?
        # Check and clone the text to avoid side effects.
        text = text.to_s.clone
        # Look for a first keyword.
        macro,range = find(text)
        while macro do
            # Delete the range from the text.
            text[range] = " " * (range.last-range.first+1)
            # Apply the block
            yield(macro,range)
            # Look for the next macro if any
            # print "text = #{text}\n"
            macro,range = find(text)
        end
    end

end
