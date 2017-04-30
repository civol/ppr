.defR repr(word,num)
   :< word
   num = num.to_i - 1
   if num > 0 then
      :< "repr(#{word},#{num})"
   end
.end
