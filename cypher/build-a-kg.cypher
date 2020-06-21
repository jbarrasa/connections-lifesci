
// create required constraint for n10s
CREATE CONSTRAINT n10s_unique_uri ON (r:Resource) ASSERT r.uri IS UNIQUE


// create graph config
CALL n10s.graphconfig.init({ handleVocabUris : "IGNORE"})


// load mesh data

UNWIND ['D009930','D006571','D011083','D046911','D006730','D045762','D002241','D008055','D000602','D009706','D045424','D001685','D001697','D004364','D020164'] as id
WITH 
'
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX meshv: <http://id.nlm.nih.gov/mesh/vocab#>
PREFIX mesh: <http://id.nlm.nih.gov/mesh/>
PREFIX neo: <neo://voc#>

CONSTRUCT {
?s a neo:MeshDescriptor; 
     neo:name ?name ;
     neo:HAS_BROADER_DESCRIPTOR ?parentDescriptor;
     meshv:pharmacologicalAction ?pharmAction ;
     meshv:dateEstablished ?date.
}
FROM <http://id.nlm.nih.gov/mesh>
WHERE { 
  {
    ?s meshv:broaderDescriptor* mesh:' + id + ' 
  }
  
  ?s rdfs:label ?name ; 
     meshv:dateEstablished ?date .
  
  optional {
    ?s meshv:broaderDescriptor ?parentDescriptor .
  }
  
  optional {
    ?s meshv:pharmacologicalAction ?pharmAction .
  }
  
} 
'
AS query, id 
CALL n10s.rdf.import.fetch(
  "https://id.nlm.nih.gov/mesh/sparql?format=TURTLE&query=" + apoc.text.urlencode(query),
  "Turtle")
YIELD terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo
RETURN id, terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo



// Load virus taxonomy

WITH '
PREFIX neo: <neo://voc#>
CONSTRUCT {
  #?cat a neo:Virus; neo:name ?catName .
  ?subCat a neo:Virus; neo:name ?subCatName ;
          neo:HAS_PARENT ?parentCat ;
          neo:LINKS_TO_MS_ACADEMIC_FOS ?msAcademicUri ;
          neo:SAME_AS_MESH_DESCRIPTOR ?meshUri ;
          neo:LINKS_TO_LOC ?locUri .
  ?parentCat a neo:Taxon .
  }

WHERE {
  #bind(wd:Q808 as ?cat)
  #?cat rdfs:label ?catName .
  #filter(lang(?catName) = "en") .
  ?subCat wdt:P171+ wd:Q808	 ;
          wdt:P171 ?parentCat;
          rdfs:label ?subCatName ;
          filter(lang(?subCatName) = "en") .
  
  optional { ?subCat wdt:P486 ?meshCode . bind(URI(concat("http://id.nlm.nih.gov/mesh/",?meshCode))  as ?meshUri) }
  optional { ?subCat wdt:P244 ?locId . bind(URI(concat("http://id.loc.gov/authorities/subjects/",?locId))  as ?locUri) }       
  optional { ?subCat wdt:P6366 ?msAcademic .  bind(URI(concat("http://ma-graph.org/entity/",?msAcademic))  as ?msAcademicUri) }
        
}     
'
AS query
CALL n10s.rdf.import.fetch(
  "https://query.wikidata.org/sparql?query=" + apoc.text.urlencode(query),
  "N-Triples",
  { headerParams: { Accept: "text/plain"}})
YIELD terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo
RETURN terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo


//Remove shortcuts

MATCH (v:Resource)<-[co:HAS_PARENT*2..]-(child)-[shortcut:HAS_PARENT]->(v)
DELETE shortcut



WITH 
'
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX meshv: <http://id.nlm.nih.gov/mesh/vocab#>
PREFIX mesh: <http://id.nlm.nih.gov/mesh/>
PREFIX neo: <neo://voc#>

CONSTRUCT {
?s a neo:MeshDescriptor; 
     neo:name ?name ;
     neo:HAS_BROADER_DESCRIPTOR ?parentDescriptor;
     meshv:pharmacologicalAction ?pharmAction ;
     meshv:dateEstablished ?date.
}
FROM <http://id.nlm.nih.gov/mesh>
WHERE { 
  {
    ?s meshv:broaderDescriptor* mesh:D014780 #viruses 
  }
  
  ?s rdfs:label ?name ; 
     meshv:dateEstablished ?date .
  
  optional {
    ?s meshv:broaderDescriptor ?parentDescriptor .
  }
  
  optional {
    ?s meshv:pharmacologicalAction ?pharmAction .
  }
  
} 
'
AS query
CALL n10s.rdf.import.fetch(
  "https://id.nlm.nih.gov/mesh/sparql?format=TURTLE&query=" + apoc.text.urlencode(query),
  "Turtle")
YIELD terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo
RETURN terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo


//Load infectious diseases

WITH '
PREFIX neo: <neo://voc#>
construct {
  ?dis a neo:InfectiousDisease ;
     neo:name ?disName ;
     neo:CAUSED_BY ?cause ;
     neo:HAS_PARENT ?parentDisease ;
     neo:LINKS_TO_MS_ACADEMIC_FOS ?msAcademicUri ;
     neo:SAME_AS_MESH_DESCRIPTOR ?meshUri ;
     neo:LINKS_TO_LOC ?locUri ;
     neo:LINKS_TO_DISEASE_ONTO ?diseaseOntoUri .
}
where { 
  ?dis wdt:P31/wdt:P279* wd:Q18123741 ;
       rdfs:label ?disName . filter(lang(?disName) = "en")

  optional { ?dis wdt:P828 ?cause }
  optional { ?dis wdt:P279 ?parentDisease .
             ?parentDisease wdt:P31/wdt:P279* wd:Q18123741 }
  optional { ?dis wdt:P486 ?meshCode . bind(URI(concat("http://id.nlm.nih.gov/mesh/",?meshCode))  as ?meshUri) }
  optional { ?dis wdt:P244 ?locId . bind(URI(concat("http://id.loc.gov/authorities/subjects/",?locId))  as ?locUri) }       
  optional { ?dis wdt:P6366 ?msAcademic .  bind(URI(concat("http://ma-graph.org/entity/",?msAcademic))  as ?msAcademicUri) }
  optional { ?dis wdt:P699 ?diseaseOntoId .  bind(URI(concat("http://purl.obolibrary.org/obo/",REPLACE(?diseaseOntoId, ":", "_")))  as ?diseaseOntoUri) }
}
'
AS query
CALL n10s.rdf.import.fetch(
  "https://query.wikidata.org/sparql?query=" + apoc.text.urlencode(query),
  "N-Triples",
  { headerParams: { Accept: "text/plain"}})
YIELD terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo
RETURN terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo




MATCH (v:Resource)<-[co:HAS_PARENT*2..]-(child)-[shortcut:HAS_PARENT]->(v)
DELETE shortcut


// add academic literature to infectious diseases
	
MATCH (x:InfectiousDisease)-[r:LINKS_TO_MS_ACADEMIC_FOS]->(msAc) 
WITH msAc.uri as uri with uri limit 20
WITH uri, '

prefix dc: <http://purl.org/dc/terms/>
  prefix fab: <http://purl.org/spar/fabio/>
  prefix foaf: <http://xmlns.com/foaf/0.1/>

  construct {
  ?pub a ?type ;
      fab:hasDiscipline ?item ;
       dc:title ?pubTitle ;
       dc:creator ?pubAuthor . 

  ?item a ?itemType ; foaf:name ?itemName .

  ?pubAuthor a ?authorType; foaf:name ?pubAuthorName .

  }
  where { 
  ?pub a ?type ;
       fab:hasDiscipline ?item ;
       dc:title ?pubTitle ;
       dc:creator ?pubAuthor  . 

  optional { ?item a ?itemType ; foaf:name ?itemName }

  filter( ?item = <' + uri +'> )  

  optional { ?pubAuthor a ?authorType; foaf:name ?pubAuthorName }
  }

'
AS query
CALL n10s.rdf.import.fetch(
  "http://ma-graph.org/sparql?query=" + apoc.text.urlencode(query),
  "N-Triples",
  { headerParams: { Accept: "text/plain"}})
YIELD terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo
RETURN uri, terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo	



//same to viruses



MATCH (x:Virus)-[r:LINKS_TO_MS_ACADEMIC_FOS]->(msAc) 
WITH msAc.uri as uri with uri limit 20
WITH uri, '

prefix dc: <http://purl.org/dc/terms/>
  prefix fab: <http://purl.org/spar/fabio/>
  prefix foaf: <http://xmlns.com/foaf/0.1/>

  construct {
  ?pub a ?type ;
      fab:hasDiscipline ?item ;
       dc:title ?pubTitle ;
       dc:creator ?pubAuthor . 

  ?item a ?itemType ; foaf:name ?itemName .

  ?pubAuthor a ?authorType; foaf:name ?pubAuthorName .

  }
  where { 
  ?pub a ?type ;
       fab:hasDiscipline ?item ;
       dc:title ?pubTitle ;
       dc:creator ?pubAuthor  . 

  optional { ?item a ?itemType ; foaf:name ?itemName }

  filter( ?item = <' + uri +'> )  

  optional { ?pubAuthor a ?authorType; foaf:name ?pubAuthorName }
  }

'
AS query
CALL n10s.rdf.import.fetch(
  "http://ma-graph.org/sparql?query=" + apoc.text.urlencode(query),
  "N-Triples",
  { headerParams: { Accept: "text/plain"}})
YIELD terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo
RETURN uri, terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo




//add chemicalcompounds and pharma products


MATCH (id:InfectiousDisease) 
WITH id.uri as uri
WITH uri, '

PREFIX neo: <neo://voc#>
construct {
  ?chemCompound a neo:ChemicalCompound ;
      neo:USED_FOR_DISEASE ?id;
      neo:ACTIVE_INGREDIENT_IN ?pharmaProduct;
      neo:SAME_AS_MESH_DESCRIPTOR ?meshUri ;            
      neo:name ?chemCompoundName . 

  ?pharmaProduct a neo:PharmaProduct ;
     neo:name ?pharmaProductName . 
}
where { 
  bind(<' + uri + '> as ?id)
  ?id wdt:P2176 ?chemCompound .
  ?chemCompound wdt:P31 wd:Q11173 ;
       rdfs:label ?chemCompoundName . 
       filter(lang(?chemCompoundName) = "en")

  optional { ?chemCompound wdt:P486 ?meshCode . bind(URI(concat("http://id.nlm.nih.gov/mesh/",?meshCode))  as ?meshUri) }    

  optional { ?chemCompound wdt:P3780 ?pharmaProduct.
             ?pharmaProduct rdfs:label ?pharmaProductName . 
            filter(lang(?pharmaProductName) = "en")
           }
}
'
AS query
CALL n10s.rdf.import.fetch(
  "https://query.wikidata.org/sparql?query=" + apoc.text.urlencode(query),
  "N-Triples",
  { headerParams: { Accept: "text/plain"}})
YIELD terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo
RETURN uri, terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo


