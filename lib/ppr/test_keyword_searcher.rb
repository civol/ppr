######################################################################
##                   Program testing KeywordSearcher                ##
######################################################################

require "ppr.rb"

# Create the keyword searcher
puts "Creating the keyword searcher..."
$searcher = KeywordSearcher.new

# Prepare the input
puts "Creating the input text..."
$input = "Histoire de rationalisation : Le Renard et les Raisins\n" +
         "Certain Renard Gascon, d'autres disent Normand,\n" + 
         "Mourant presque de faim, vit au haut d'une treille\n" +
         "Des Raisins mûrs apparemment,\n" +
         "Et couverts d'une peau vermeille.\n" +
         "Le galand en eût fait volontiers un repas ;\n" +
         "Mais comme il n'y pouvait atteindre :\n" +
         "\"Ils sont trop verts, dit-il, et bons pour des goujats. \"\n" +
         "Fit-il pas mieux que de se plaindre ?"

# Prepare the keywords to search
$keywords = [ "Renard", "Normand", "an" ]
$keywords.each.with_index do |keyword,i| 
    puts "Adding keyword #{keyword} associated with #{i}..."
    $searcher[keyword] = i
end

# Prepare the expected result.
$expected = [ [0,[33,38]], [0,[63,68]], [1,[94,100]], [2,[107,108]],[2,[224,225]] ]


# Interate over the keywords founds in the text.
ok = true
$searcher.each_in($input).with_index do |entry_range, i|
    entry, range = *entry_range
    print "Got entry=#{entry} (#{$keywords[entry]}) at range=#{range}..."
    unless $input[range[0]..range[1]] == $keywords[entry] then
        puts "\nError: at range=#{range} there is #{$input[range[0]..range[1]]}"
        ok = false
    end
    unless [entry,range] == $expected[i] then
        puts "\nError: invalid result."
        puts "Got #{[entry,range]} but expecting #{$expected[i]}."
        ok = false
    end
    puts " ok."
end



if ok then
    puts "Success." 
else
    puts "Failure." 
end
