// 00. initialise DB
CREATE CONSTRAINT n10s_unique_uri ON (r:Resource) ASSERT r.uri IS UNIQUE ;

CALL n10s.graphconfig.init({ handleVocabUris : "IGNORE"}) ;




// 01.AppL:Wikidata Virus Taxonomy
WITH '
PREFIX neo: <neo://voc#>
CONSTRUCT {
 ?virus a neo:Virus, neo:WikidataNode ; neo:name ?virusName ;
          neo:HAS_PARENT ?parentVirus ;
          neo:LINKS_TO_MS_ACADEMIC_FOS ?msAcademicUri ;
          neo:SAME_AS_MESH_DESCRIPTOR ?meshUri .
  ?parentVirus a neo:Virus .
  }
WHERE {
  ?virus wdt:P171+ wd:Q808	 ;
          wdt:P171 ?parentVirus;
          rdfs:label ?virusName ;
          filter(lang(?virusName) = "en") .

  optional { ?virus wdt:P486 ?meshCode .
             bind(URI(concat("http://id.nlm.nih.gov/mesh/",?meshCode))  as ?meshUri) }
  optional { ?virus wdt:P6366 ?msAcademic .
             bind(URI(concat("http://ma-graph.org/entity/",?msAcademic))  as ?msAcademicUri) }

}
'
AS query
CALL n10s.rdf.import.fetch(
  "https://query.wikidata.org/sparql?query=" + apoc.text.urlencode(query),
  "N-Triples",
  { headerParams: { Accept: "text/plain"}})
YIELD terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo
RETURN terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo




// 02.Q:SARS coronavirus taxonomy
MATCH taxonomy = (v:Virus)-[:HAS_PARENT*]->(root)
WHERE v.name = "severe acute respiratory syndrome coronavirus"
     AND NOT (root)-[:HAS_PARENT]->()
RETURN taxonomy



//03.AppL:MeSH Virus Taxonomy

WITH
'
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX meshv: <http://id.nlm.nih.gov/mesh/vocab#>
PREFIX mesh: <http://id.nlm.nih.gov/mesh/>
PREFIX neo: <neo://voc#>

CONSTRUCT {
?s a neo:MeshDescriptor, neo:Virus ;
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




// 04.Q:Compare MeSH and Wikidata Virus Taxonomies

MATCH wikidataTaxonomy = (v:Virus)-[:HAS_PARENT*]->(root)
WHERE v.name contains "severe acute respiratory" AND NOT (root)-[:HAS_PARENT]->()
WITH wikidataTaxonomy, v


MATCH meshTaxonomy = (v)-[:SAME_AS_MESH_DESCRIPTOR]->()-[:HAS_BROADER_DESCRIPTOR*]->(root)
WHERE  NOT (root)-[:HAS_PARENT]->()
RETURN wikidataTaxonomy, meshTaxonomy




//05.AppL:Wikidata Infectious diseases

WITH '
PREFIX neo: <neo://voc#>
construct {
  ?dis a neo:InfectiousDisease , neo:WikidataNode ;
     neo:name ?disName ;
     neo:CAUSED_BY ?cause ;
     neo:HAS_PARENT ?parentDisease ;
     neo:LINKS_TO_MS_ACADEMIC_FOS ?msAcademicUri ;
     neo:SAME_AS_MESH_DESCRIPTOR ?meshUri ;
     neo:LINKS_TO_DISEASE_ONTO ?diseaseOntoUri .
}
where {
  ?dis wdt:P31/wdt:P279* wd:Q18123741 ;
       rdfs:label ?disName . filter(lang(?disName) = "en")

  optional { ?dis wdt:P828 ?cause }
  optional { ?dis wdt:P279 ?parentDisease .
             ?parentDisease wdt:P31/wdt:P279* wd:Q18123741 }
  optional { ?dis wdt:P486 ?meshCode . bind(URI(concat("http://id.nlm.nih.gov/mesh/",?meshCode))  as ?meshUri) }
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




// 06.Q:Explore the Wikidata Infectious Disease Taxonomy
MATCH wikidataTaxonomy = (id:InfectiousDisease)-[:HAS_PARENT*]->(root)
WHERE id.name = "COVID-19" AND NOT (root)-[:HAS_PARENT]->()
WITH wikidataTaxonomy
UNWIND nodes(wikidataTaxonomy) as wdn
MATCH (wdn)-[cb:CAUSED_BY]->(v:Virus)
RETURN wikidataTaxonomy, cb, v



//07.L:MesH Disease descriptors (look at tree view first)


UNWIND ['D007239','D009369','D009140','D004066','D009057','D012140','D010038','D009422','D005128','D052801','D005261','D002318','D006425','D009358','D017437','D009750','D004700','D007154','D007280','D000820','D013568','D009784','D064419','D014947'] as id
WITH
'
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX meshv: <http://id.nlm.nih.gov/mesh/vocab#>
PREFIX mesh: <http://id.nlm.nih.gov/mesh/>
PREFIX neo: <neo://voc#>

CONSTRUCT {
?s a neo:MeshDescriptor, neo:Disease;
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




//08.Q:MeSH&Wikidata Disease taxonomies

MATCH wikidataTaxonomy = (id:InfectiousDisease)-[:HAS_PARENT*]->(root)
WHERE id.name = "severe acute respiratory syndrome" AND NOT (root)-[:HAS_PARENT]->()
WITH wikidataTaxonomy, id
MATCH meshTaxonomy = (id)-[:SAME_AS_MESH_DESCRIPTOR]->(m)-[:HAS_BROADER_DESCRIPTOR*]->(root)
WHERE NOT (root)-[:HAS_BROADER_DESCRIPTOR]->()
RETURN wikidataTaxonomy, meshTaxonomy



//09.L:Wikidata Chemical Compounds & Pharma Products


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





// 10.L:MeSH Chemicals & Drugs (look at tree view)

UNWIND ['D009930','D006571','D011083','D046911','D006730','D045762','D002241','D008055','D000602','D009706','D045424','D001685','D001697','D004364','D020164'] as id
WITH
'
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX meshv: <http://id.nlm.nih.gov/mesh/vocab#>
PREFIX mesh: <http://id.nlm.nih.gov/mesh/>
PREFIX neo: <neo://voc#>

CONSTRUCT {
?s a neo:MeshDescriptor, neo:ChemOrDrug ;
     neo:name ?name ;
     neo:HAS_BROADER_DESCRIPTOR ?parentDescriptor;
     meshv:PHARMACOLOGICAL_ACTION ?pharmAction ;
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




//11.L:Disease Ontology (3 steps)

call n10s.onto.import.fetch("http://purl.obolibrary.org/obo/doid.owl","RDF/XML");


//add extra label
MATCH (c:Class) SET c:DO_Disease;


// add cross references
call n10s.rdf.stream.fetch("http://purl.obolibrary.org/obo/doid.owl","RDF/XML", { limit : 999999}) yield subject, predicate, object
where predicate = "http://www.geneontology.org/formats/oboInOwl#hasDbXref" and object starts with "MESH:"
MATCH (doe:Resource { uri: subject}),
(mesh:Resource { uri: "http://id.nlm.nih.gov/mesh/" + substring(object,5)})
MERGE (doe)-[:SAME_AS_MESH_DESCRIPTOR]->(mesh);



//12.Q:Taxonomy Reconciliation (triangle analysis)

//Normal scenario
MATCH path = (wdid:InfectiousDisease)-[:LINKS_TO_DISEASE_ONTO]->(do)-[:SAME_AS_MESH_DESCRIPTOR]->(md)<-[:SAME_AS_MESH_DESCRIPTOR]-(wdid)
return path limit 10;

//incomplete scenario
MATCH path = (wdid:InfectiousDisease)-[:LINKS_TO_DISEASE_ONTO]->(do)-[:SAME_AS_MESH_DESCRIPTOR]->(md)
WHERE NOT (wdid)-[:SAME_AS_MESH_DESCRIPTOR]->(md)
return path limit 10;

//triples to be added to the wikidata kb
MATCH path = (wdid:InfectiousDisease)-[:LINKS_TO_DISEASE_ONTO]->(do)-[:SAME_AS_MESH_DESCRIPTOR]->(md)
WHERE NOT (wdid)-[:SAME_AS_MESH_DESCRIPTOR]->(md)
RETURN wdid.uri as subject, "http://www.wikidata.org/prop/direct/P486" as predicate, n10s.rdf.getIRILocalName(md.uri) as object;





//13.0Q:cross-domain query
MATCH p1 = (ccmd:MeshDescriptor { uri: 'http://id.nlm.nih.gov/mesh/D003139' })<-[:SAME_AS_MESH_DESCRIPTOR]-(id:InfectiousDisease)
MATCH p2 = (v:Virus)-[:CAUSED_BY]-(id)-[:USED_FOR_DISEASE]-(chem)-[:ACTIVE_INGREDIENT_IN]-()
RETURn p1, p2



//13.L:SARS Virus Academic Literature from MS Academic Graph
MATCH tax = (v:Virus)-[:HAS_PARENT*]->(root)
WHERE v.name = "severe acute respiratory syndrome coronavirus" AND NOT (root)-[:HAS_PARENT]->()
UNWIND nodes(tax) as node
MATCH (node)-[:LINKS_TO_MS_ACADEMIC_FOS]->(fos)
WITH node.uri as diseaseUri, node.name as diseaseName, fos.name as fosName, fos.uri as fosUri, '

  prefix dc: <http://purl.org/dc/terms/>
  prefix fab: <http://purl.org/spar/fabio/>
  prefix foaf: <http://xmlns.com/foaf/0.1/>

  construct {
  ?pub a ?type ;
      fab:HAS_DISCIPLINE ?item ;
      dc:title ?pubTitle ;
      dc:CREATOR ?pubAuthor .

  ?item a ?itemType ; foaf:name ?itemName .

  ?pubAuthor a ?authorType; foaf:name ?pubAuthorName .
  } where {
  ?pub a ?type ;
       fab:hasDiscipline ?item ;
       dc:title ?pubTitle ;
       dc:creator ?pubAuthor  .

  optional { ?item a ?itemType ; foaf:name ?itemName }

  filter( ?item = <' + fos.uri +'> )

  optional { ?pubAuthor a ?authorType; foaf:name ?pubAuthorName }
  }
' AS query
CALL n10s.rdf.import.fetch(
  "http://ma-graph.org/sparql?query=" + apoc.text.urlencode(query),
  "N-Triples",
  { headerParams: { Accept: "text/plain"}})
YIELD terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo
RETURN diseaseUri, diseaseName, fosName, fosUri, terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo






//14.L:COVID-19 Academic Literature from Ms Academic Graph
MATCH tax = (id:InfectiousDisease)-[:HAS_PARENT*]->(root)
WHERE id.name = "COVID-19" AND NOT (root)-[:HAS_PARENT]->()
UNWIND nodes(tax) as node
MATCH (node)-[:LINKS_TO_MS_ACADEMIC_FOS]->(fos)
WITH node.uri as diseaseUri, node.name as diseaseName, fos.name as fosName, fos.uri as fosUri, '

prefix dc: <http://purl.org/dc/terms/>
  prefix fab: <http://purl.org/spar/fabio/>
  prefix foaf: <http://xmlns.com/foaf/0.1/>

  construct {
  ?pub a ?type ;
      fab:HAS_DISCIPLINE ?item ;
       dc:title ?pubTitle ;
       dc:CREATOR ?pubAuthor .

  ?item a ?itemType ; foaf:name ?itemName .

  ?pubAuthor a ?authorType; foaf:name ?pubAuthorName .

  }
  where {
  ?pub a ?type ;
       fab:hasDiscipline ?item ;
       dc:title ?pubTitle ;
       dc:creator ?pubAuthor  .

  optional { ?item a ?itemType ; foaf:name ?itemName }

  filter( ?item = <' + fos.uri +'> )

  optional { ?pubAuthor a ?authorType; foaf:name ?pubAuthorName }
  }

'
AS query
CALL n10s.rdf.import.fetch(
  "http://ma-graph.org/sparql?query=" + apoc.text.urlencode(query),
  "N-Triples",
  { headerParams: { Accept: "text/plain"}})
YIELD terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo
RETURN diseaseUri, diseaseName, fosName, fosUri, terminationStatus, triplesLoaded, triplesParsed, namespaces, extraInfo






//15.Q:Relevant fields of study for a given virus (graph view)
MATCH tax = (v:Virus { name: "severe acute respiratory syndrome coronavirus" })-[:HAS_PARENT*]->(root)
WHERE NOT (root)-[:HAS_PARENT]->()
WITH tax
UNWIND nodes(tax) as n
MATCH (n)-[ltf:LINKS_TO_MS_ACADEMIC_FOS]->(fos)
RETURN tax, ltf, fos





//16.Q:Relevant literature for a given virus (graph view)

MATCH tax = (v:Virus { name : "severe acute respiratory syndrome coronavirus"})-[:HAS_PARENT*]->(root)
WHERE NOT (root)-[:HAS_PARENT]->()
WITH tax
UNWIND nodes(tax) as n
MATCH (n)-[ltf:LINKS_TO_MS_ACADEMIC_FOS]->(fos)<-[:hasDiscipline]-(p:Paper)
RETURN fos.name as fieldOfStudy, p.title as title




//20.Aux:Remove shortcuts

MATCH (v:Resource)<-[co:HAS_PARENT*2..]-(child)-[shortcut:HAS_PARENT]->(v)
DELETE shortcut

