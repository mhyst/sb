BEGIN {
	FS = "[/-]"
}

{
	if (season > -1 && $5 < season)
		next
	if (season > -1 && chapter > -1)
		if ($5 == season && $7 < chapter)
			next
	print $0
}