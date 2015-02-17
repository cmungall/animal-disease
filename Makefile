OBO:= http://purl.obolibrary.org/obo

all: zoodi.owl zoodi.ttl zoodi.obo

# ----------------------------------------
# DBPEDIA
# ----------------------------------------

# we download triples for each category individually

CATEGORIES :=\
Amphibian_diseases\
Animal_diseases\
Bat_diseases\
Bird_diseases\
Bovine_diseases\
Cancer_in_cats\
Cancer_in_cats_and_dogs\
Cancer_in_dogs\
Cat_diseases\
Coral_diseases\
Diseases_and_parasites_of_crustaceans\
Diseases_of_the_ruminants\
Dog_diseases\
Fish_diseases\
Genetic_animal_diseases\
Horse_diseases\
Insect_diseases\
Parasites_of_birds\
Poultry_diseases\
Primate_diseases\
Rabbit_diseases\
Rodent_diseases\
Sheep_and_goat_diseases\
Swine_diseases\
Types_of_animal_cancers\
Wildlife_diseases\
Zoonoses\
Zoonotic_bacterial_diseases


CATFILES = $(patsubst %, dbpedia_cat_%.pro, $(CATEGORIES))

all_cats: $(CATFILES)

dbpedia_cat_%.pro:
	 blip ontol-sparql-remote "SELECT * WHERE {  ?x <http://purl.org/dc/terms/subject> <http://dbpedia.org/resource/Category:$*> }" -write_prolog > $@.tmp && sort -u $@.tmp > $@

dbpedia_all_Animal_diseases.pro: $(CATFILES)
	 cat $^ | sort -u | grep -v outbreak > $@


#dbpedia_all_Animal_diseasesT.pro:
#	 blip ontol-sparql-remote "SELECT ?x WHERE {  ?x <http://purl.org/dc/terms/subject> [skos:broader  <http://dbpedia.org/resource/Category:Animal_diseases> ] }" -write_prolog > $@.tmp && sort -u $@.tmp > $@

#dbpedia_all_Animal_diseases.pro:
#	 blip ontol-sparql-remote "SELECT ?disease ?cat WHERE {  ?disease <http://purl.org/dc/terms/subject> ?cat . ?cat skos:broader*  <http://dbpedia.org/resource/Category:Animal_diseases> }" -write_prolog > $@.tmp && sort -u $@.tmp > $@


all_triples: $(patsubst %, triples-cat_%.pro, $(CATEGORIES))

triples-%.pro: dbpedia_%.pro
	blip-findall -debug sparql -i $< -u sparql_util "row(A),dbpedia_query_links(A,row(S,P,O),1000,[])" -select "rdf(S,P,O)" -write_prolog > $@.tmp && mv $@.tmp $@
#	blip-findall -debug sparql -i $< -u sparql_util "row(A),dbpedia_query_links(A,row(S,P,O),1000,[sameAs('http://dbpedia.org/property/redirect')])" -select "rdf(S,P,O)" -write_prolog > $@
.PRECIOUS: triples-%.pro

all_obo: $(patsubst %, ont-cat_%.obo, $(CATEGORIES))

ont-%.obo: triples-%.pro
	blip -i $< -u ontol_bridge_from_dbpedia io-convert -to obo > $@

#zoodi-wp.obo: $(patsubst %, ont-cat_%.obo, $(CATEGORIES))
#	owltools $^ --merge-support-ontologies --set-ontology-id $(OBO)/zoodi.owl -o -f obo $@

zoodi-wp.obo: $(patsubst %, ont-cat_%.obo, $(CATEGORIES))
	obo-cat.pl $^ --merge-support-ontologies > $@.tmp && owltools $@.tmp --set-ontology-id $(OBO)/zoodi.owl -o -f obo $@


wikidata-xrefs.obo: zoodi-wp.obo
	obo-filter-tags.pl -t id -t xref $< | perl -ne 'print unless /^xref: [^Wikidata]/' > $@

zoodi-pre.obo: zoodi-wp.obo 
	obo-map-ids.pl --use-xref wikidata-xrefs.obo $< > $@.tmp && grep -v ^owl-axioms $@.tmp > $@

zoodi.obo: zoodi-pre.obo exclude.obo
	obo-subtract.pl $^ > $@.tmp && mv $@.tmp $@

zoodi.ttl: zoodi.obo
	owltools $< -o -f ttl $@

zoodi.owl: zoodi.ttl
	owltools $< -o $@

