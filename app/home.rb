#!/usr/bin/env ruby

require 'sinatra'
require 'sequel'
require 'sparql/client'
require 'set'

DB = Sequel.connect('postgres://joseph@localhost/nbia')
TS = SPARQL::Client.new('http://localhost:7200/repositories/prism')
set :bind, '0.0.0.0'

get '/' do
  @results = TS.query(%[PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX obo: <http://purl.obolibrary.org/obo/>
select * where {
    ?organ rdfs:subClassOf* obo:UBERON_0001062 .
    ?organ rdfs:label ?name .
} ORDER BY ?name])
  erb :sparql
end

post '/' do
  @results = TS.query(%[
PREFIX inheres: <http://purl.obolibrary.org/obo/RO_0000052>
PREFIX human: <http://purl.obolibrary.org/obo/NCBITaxon_9606>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX identifier: <http://purl.obolibrary.org/obo/IAO_0020000>
PREFIX denotes: <http://purl.obolibrary.org/obo/IAO_0000219>
PREFIX cancer: <http://purl.obolibrary.org/obo/DOID_162>
PREFIX has_part: <http://purl.obolibrary.org/obo/BFO_0000051>
select ?idl ?location_name {
?person a human: .
?id denotes: ?person ;
    a identifier: ;
    rdfs:label ?idl .
?person has_part: ?o .
?d inheres: ?o ;
   a cancer: .
?o a <#{params[:organ]}> ;
   a ?location .
?location rdfs:label ?location_name .
}])
  @ids = Set[]
  @locations = Set[]
  @results.each do |id|
    @ids << id.idl.to_s
    @locations << id.location_name.to_s
  end
  @other = DB[%{
select patient_id, series_instance_uid, image_type, count(*) from general_image
where patient_id in ?
group by series_instance_uid, image_type, patient_id
              }, @ids.to_a]
  erb :index
end

get '/to_download/:series_instance_uid' do |uid|
  content_type 'application/x-nbia-manifest-file'
  attachment "download.tcia"
  %{downloadServerUrl=https://public.cancerimagingarchive.net/nbia-download/servlet/DownloadServlet
includeAnnotation=true
noOfrRetry=4
manifestVersion=3.0
ListOfSeriesToDownload=
#{uid}}
end
