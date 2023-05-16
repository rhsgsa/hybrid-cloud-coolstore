for r in `vesctl configuration list registration -n system --outfmt=yaml| yq .items[].name`
do
	vesctl configuration delete registration $r -n system
done

