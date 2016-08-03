# ----------------------------------------
# CONSTANTS
# ----------------------------------------

OBO:= http://purl.obolibrary.org/obo

# ----------------------------------------
# TOP-LEVEL TARGET
# ----------------------------------------

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

# For each category, generate a list of articles in that category;
# (each article is stored as a prolog fact of type row/1, with the value being the dbpedia URI)
dbpedia_cat_%.pro:
	 blip ontol-sparql-remote "SELECT * WHERE {  ?x <http://purl.org/dc/terms/subject> <http://dbpedia.org/resource/Category:$*> }" -write_prolog > $@.tmp && sort -u $@.tmp > $@

# all pages in all categories
dbpedia_all_Animal_diseases.pro: $(CATFILES)
	 cat $^ | sort -u | grep -v outbreak > $@


#dbpedia_all_Animal_diseasesT.pro:
#	 blip ontol-sparql-remote "SELECT ?x WHERE {  ?x <http://purl.org/dc/terms/subject> [skos:broader  <http://dbpedia.org/resource/Category:Animal_diseases> ] }" -write_prolog > $@.tmp && sort -u $@.tmp > $@

#dbpedia_all_Animal_diseases.pro:
#	 blip ontol-sparql-remote "SELECT ?disease ?cat WHERE {  ?disease <http://purl.org/dc/terms/subject> ?cat . ?cat skos:broader*  <http://dbpedia.org/resource/Category:Animal_diseases> }" -write_prolog > $@.tmp && sort -u $@.tmp > $@


all_triples: $(patsubst %, triples-cat_%.pro, $(CATEGORIES))

# For each category, we take each article dbpedia URI and find all triples with this as a subject or object
triples-%.pro: dbpedia_%.pro
	blip-findall -debug sparql -i $< -u sparql_util "row(A),dbpedia_query_links(A,row(S,P,O),1000,[])" -select "rdf(S,P,O)" -write_prolog > $@.tmp && mv $@.tmp $@
#	blip-findall -debug sparql -i $< -u sparql_util "row(A),dbpedia_query_links(A,row(S,P,O),1000,[sameAs('http://dbpedia.org/property/redirect')])" -select "rdf(S,P,O)" -write_prolog > $@
.PRECIOUS: triples-%.pro

all_obo: $(patsubst %, ont-cat_%.obo, $(CATEGORIES))

# translate triples to .obo format
# Each class will have ID of form 'Wikipedia:Foo_bar'
ont-%.obo: triples-%.pro
	blip -i $< -u ontol_bridge_from_dbpedia io-convert -to obo > $@

#zoodi-wp.obo: $(patsubst %, ont-cat_%.obo, $(CATEGORIES))
#	owltools $^ --merge-support-ontologies --set-ontology-id $(OBO)/zoodi.owl -o -f obo $@

# merge all per-category obos together
zoodi-wp.obo: $(patsubst %, ont-cat_%.obo, $(CATEGORIES))
	obo-cat.pl $^ --merge-support-ontologies > $@.tmp && owltools $@.tmp --set-ontology-id $(OBO)/zoodi.owl -o -f obo $@

# generate a separate mapping file, e.g. Wikipedia:Abomasitis -> Wikidata:Q3646463
wikidata-xrefs.obo: zoodi-wp.obo
	obo-filter-tags.pl -t id -t xref $< | perl -ne 'print unless /^xref: [^Wikidata]/' > $@

# map all IDs to Wikidata IDs (where a mapping exists)
zoodi-pre.obo: zoodi-wp.obo wikidata-xrefs.obo
	obo-map-ids.pl --use-xref wikidata-xrefs.obo $< > $@.tmp && grep -v ^owl-axioms $@.tmp > $@

# exclude.obo is a manually curated list of obo stanzas of classes that are not relevant and should be excluded;
# we subtract out anything in this blacklist
zoodi-1.obo: zoodi-pre.obo exclude.obo
	obo-subtract.pl $^ > $@.tmp && mv $@.tmp $@

# merge the ontology with the list of mappings to other sources
zoodi.obo: zoodi-1.obo xrefs-zoodi-to-doid.obo xrefs-zoodi-to-ncbitaxon.obo
	obo-merge-tags.pl -t xref $^ > $@.tmp && mv $@.tmp $@

zoodi.ttl: zoodi.obo
	owltools $< -o -f ttl $@

zoodi.owl: zoodi.ttl
	owltools $< -o $@

## ALIGN

align-zoodi-to-ncbitaxon.tsv: zoodi.obo
	blip-findall -i disjoints.obo -i ignore.pro -u metadata_nlp -i $< -r taxonomy -goal index_entity_pair_label_match "entity_pair_label_reciprocal_best_intermatch(X,Y,S),class(X),class(Y),\\+disjoint_from(X,Y),\\+disjoint_from(Y,X)" -select "m(X,Y,S)" -use_tabs -label -no_pred > $@.tmp && sort -u $@.tmp > $@

align-zoodi-to-doid.tsv: zoodi.obo
	blip-findall -i disjoints.obo -i ignore.pro -u metadata_nlp -i $< -r disease -goal index_entity_pair_label_match "entity_pair_label_reciprocal_best_intermatch(X,Y,S),class(X),class(Y),\\+disjoint_from(X,Y),\\+disjoint_from(Y,X)" -select "m(X,Y,S)" -use_tabs -label -no_pred > $@.tmp && sort -u $@.tmp > $@


align-zcat-to-ncbitaxon.tsv: wikipedia-categories.obo
	blip-findall -i disjoints.obo -i ignore.pro -u metadata_nlp -i $< -r taxonomy -goal index_entity_pair_label_match "entity_pair_label_reciprocal_best_intermatch(X,Y,S),class(X),class(Y),\\+disjoint_from(X,Y),\\+disjoint_from(Y,X),\\+entity_xref(X,_)" -select "m(X,Y,S)" -use_tabs -label -no_pred > $@.tmp && sort -u $@.tmp > $@

align-zcat-to-doid.tsv: wikipedia-categories.obo
	blip-findall -i disjoints.obo -i ignore.pro -u metadata_nlp -i $< -r disease -goal index_entity_pair_label_match "entity_pair_label_reciprocal_best_intermatch(X,Y,S),class(X),class(Y),\\+disjoint_from(X,Y),\\+disjoint_from(Y,X),\\+entity_xref(X,_)" -select "m(X,Y,S)" -use_tabs -label -no_pred > $@.tmp && sort -u $@.tmp > $@

align-zcat-to-hp.tsv: wikipedia-categories.obo
	blip-findall -i disjoints.obo -i ignore.pro -u metadata_nlp -i $< -r HP -goal index_entity_pair_label_match "entity_pair_label_reciprocal_best_intermatch(X,Y,S),class(X),class(Y),\\+disjoint_from(X,Y),\\+disjoint_from(Y,X),\\+entity_xref(X,_)" -select "m(X,Y,S)" -use_tabs -label -no_pred > $@.tmp && sort -u $@.tmp > $@

xrefs-%.obo: align-%.tsv
	cut -f1-4 $< | sort -u | grep ^Wik | tbl2obolinks.pl --rel xref > $@.tmp && mv $@.tmp $@

taxon-triples.tsv:
	blip-findall -r taxonomy -i zoodi.obo -i wikipedia-categories.obo "entity_xref_idspace(D,X,'NCBITaxon'),subclassRT(D,D2),(parent(D2,R,Y);R=caused_by,D2\\=D,entity_xref(D2,Y)),id_idspace(Y,'NCBITaxon')" -select "x(X,R,Y)" -no_pred -label -use_tabs > $@


