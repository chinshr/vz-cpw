text = "The call is the first known contact between a U.S. president or president-elect with a Taiwanese leader since the United States broke diplomatic relations with the island in 1979. China considers Taiwan a province, and news of the official outreach by Donald Trump is likely to infuriate the regional military and economic power."

# Keyword Extraction

results = AlchemyAPI.search(:keyword_extraction, text: text)
 => [{"relevance"=>"0.990504", "text"=>"Donald Trump"}, {"relevance"=>"0.969806", "text"=>"diplomatic relations"}, {"relevance"=>"0.962164", "text"=>"Taiwanese leader"}, {"relevance"=>"0.900615", "text"=>"U.S. president"}, {"relevance"=>"0.812872", "text"=>"United States"}, {"relevance"=>"0.750445", "text"=>"official outreach"}, {"relevance"=>"0.733865", "text"=>"economic power"}, {"relevance"=>"0.487022", "text"=>"president-elect"}, {"relevance"=>"0.22155", "text"=>"contact"}, {"relevance"=>"0.217081", "text"=>"island"}, {"relevance"=>"0.210378", "text"=>"China"}, {"relevance"=>"0.209529", "text"=>"province"}]


## With `emotion`

results = AlchemyAPI.search(:keyword_extraction, text: text, emotion: 1)
 => [{"emotions"=>{"anger"=>"0.129245", "disgust"=>"0.189783", "fear"=>"0.578291", "joy"=>"0.037894", "sadness"=>"0.173874"}, "relevance"=>"0.990504", "text"=>"Donald Trump"}, {"emotions"=>{"anger"=>"0.123973", "disgust"=>"0.208563", "fear"=>"0.156169", "joy"=>"0.255887", "sadness"=>"0.361523"}, "relevance"=>"0.969806", "text"=>"diplomatic relations"}, {"emotions"=>{"anger"=>"0.123973", "disgust"=>"0.208563", "fear"=>"0.156169", "joy"=>"0.255887", "sadness"=>"0.361523"}, "relevance"=>"0.962164", "text"=>"Taiwanese leader"}, {"emotions"=>{"anger"=>"0.123973", "disgust"=>"0.208563", "fear"=>"0.156169", "joy"=>"0.255887", "sadness"=>"0.361523"}, "relevance"=>"0.900615", "text"=>"U.S. president"}, {"emotions"=>{"anger"=>"0.123973", "disgust"=>"0.208563", "fear"=>"0.156169", "joy"=>"0.255887", "sadness"=>"0.361523"}, "relevance"=>"0.812872", "text"=>"United States"}, {"emotions"=>{"anger"=>"0.129245", "disgust"=>"0.189783", "fear"=>"0.578291", "joy"=>"0.037894", "sadness"=>"0.173874"}, "relevance"=>"0.750445", "text"=>"official outreach"}, {"emotions"=>{"anger"=>"0.129245", "disgust"=>"0.189783", "fear"=>"0.578291", "joy"=>"0.037894", "sadness"=>"0.173874"}, "relevance"=>"0.733865", "text"=>"economic power"}, {"emotions"=>{"anger"=>"0.123973", "disgust"=>"0.208563", "fear"=>"0.156169", "joy"=>"0.255887", "sadness"=>"0.361523"}, "relevance"=>"0.487022", "text"=>"president-elect"}, {"emotions"=>{"anger"=>"0.123973", "disgust"=>"0.208563", "fear"=>"0.156169", "joy"=>"0.255887", "sadness"=>"0.361523"}, "relevance"=>"0.22155", "text"=>"contact"}, {"emotions"=>{"anger"=>"0.123973", "disgust"=>"0.208563", "fear"=>"0.156169", "joy"=>"0.255887", "sadness"=>"0.361523"}, "relevance"=>"0.217081", "text"=>"island"}, {"emotions"=>{"anger"=>"0.075905", "disgust"=>"0.313901", "fear"=>"0.080858", "joy"=>"0.315906", "sadness"=>"0.298669"}, "relevance"=>"0.210378", "text"=>"China"}, {"emotions"=>{"anger"=>"0.075905", "disgust"=>"0.313901", "fear"=>"0.080858", "joy"=>"0.315906", "sadness"=>"0.298669"}, "relevance"=>"0.209529", "text"=>"province"}]

## With `sentiment`

results = AlchemyAPI.search(:keyword_extraction, text: text, sentiment: 1)
 => [{"relevance"=>"0.990504", "sentiment"=>{"score"=>"-0.512024", "type"=>"negative"}, "text"=>"Donald Trump"}, {"relevance"=>"0.969806", "sentiment"=>{"type"=>"neutral"}, "text"=>"diplomatic relations"}, {"relevance"=>"0.962164", "sentiment"=>{"type"=>"neutral"}, "text"=>"Taiwanese leader"}, {"relevance"=>"0.900615", "sentiment"=>{"type"=>"neutral"}, "text"=>"U.S. president"}, {"relevance"=>"0.812872", "sentiment"=>{"type"=>"neutral"}, "text"=>"United States"}, {"relevance"=>"0.750445", "sentiment"=>{"score"=>"-0.512024", "type"=>"negative"}, "text"=>"official outreach"}, {"relevance"=>"0.733865", "sentiment"=>{"score"=>"-0.512024", "type"=>"negative"}, "text"=>"economic power"}, {"relevance"=>"0.487022", "sentiment"=>{"type"=>"neutral"}, "text"=>"president-elect"}, {"relevance"=>"0.22155", "sentiment"=>{"type"=>"neutral"}, "text"=>"contact"}, {"relevance"=>"0.217081", "sentiment"=>{"type"=>"neutral"}, "text"=>"island"}, {"relevance"=>"0.210378", "sentiment"=>{"type"=>"neutral"}, "text"=>"China"}, {"relevance"=>"0.209529", "sentiment"=>{"type"=>"neutral"}, "text"=>"province"}]

# Targeted Sentiment Analysis

nogo = AlchemyAPI.search(:targeted_sentiment_analysis, text: text)
 => nil

# Relation Extraction

results = AlchemyAPI.search(:relation_extraction, text: text)
 => [{"sentence"=>"The call is the first known contact between a U.S. president or president-elect with a Taiwanese leader since the United States broke diplomatic relations with the island in 1979.", "subject"=>{"text"=>"The call"}, "action"=>{"text"=>"is", "lemmatized"=>"be", "verb"=>{"text"=>"be", "tense"=>"present"}}, "object"=>{"text"=>"the first known contact between a U.S. president or president-elect with a Taiwanese leader"}}, {"sentence"=>"The call is the first known contact between a U.S. president or president-elect with a Taiwanese leader since the United States broke diplomatic relations with the island in 1979.", "subject"=>{"text"=>"the United States"}, "action"=>{"text"=>"broke", "lemmatized"=>"break", "verb"=>{"text"=>"break", "tense"=>"past"}}, "object"=>{"text"=>"diplomatic relations with the island"}}, {"sentence"=>" China considers Taiwan a province, and news of the official outreach by Donald Trump is likely to infuriate the regional military and economic power.", "subject"=>{"text"=>"China"}, "action"=>{"text"=>"considers", "lemmatized"=>"consider", "verb"=>{"text"=>"consider", "tense"=>"present"}}, "object"=>{"text"=>"Taiwan"}}, {"sentence"=>" China considers Taiwan a province, and news of the official outreach by Donald Trump is likely to infuriate the regional military and economic power.", "subject"=>{"text"=>"news of the official outreach by Donald Trump"}, "action"=>{"text"=>"is", "lemmatized"=>"be", "verb"=>{"text"=>"be", "tense"=>"present"}}, "object"=>{"text"=>"likely to infuriate the regional military and economic power"}}, {"sentence"=>" China considers Taiwan a province, and news of the official outreach by Donald Trump is likely to infuriate the regional military and economic power.", "subject"=>{"text"=>"news of the official outreach by Donald Trump"}, "action"=>{"text"=>"to infuriate", "lemmatized"=>"to infuriate", "verb"=>{"text"=>"infuriate", "tense"=>"future"}}, "object"=>{"text"=>"the regional military and economic power"}}]

# Sentiment Analysis

results = AlchemyAPI.search(:sentiment_analysis, text: text)
 => {"score"=>"-0.452419", "type"=>"negative"}

# Taxonomy

results = AlchemyAPI.search(:taxonomy, text: text)
 => [{"label"=>"/law, govt and politics/government", "score"=>"0.422036"}, {"confident"=>"no", "label"=>"/travel/tourist destinations/japan", "score"=>"0.14603"}, {"confident"=>"no", "label"=>"/law, govt and politics/government/embassies and consulates", "score"=>"0.141832"}]

# Text Categorization

results = AlchemyAPI.search(:text_categorization, text: text)
 => {"status"=>"OK", "usage"=>"By accessing AlchemyAPI or using information generated by AlchemyAPI, you are agreeing to be bound by the AlchemyAPI Terms of Use: http://www.alchemyapi.com/company/terms.html", "url"=>"", "language"=>"english", "category"=>"culture_politics", "score"=>"0.807868"}

# Language Detection

results = AlchemyAPI.search(:language_detection, text: text)
 => {"status"=>"OK", "usage"=>"By accessing AlchemyAPI or using information generated by AlchemyAPI, you are agreeing to be bound by the AlchemyAPI Terms of Use: http://www.alchemyapi.com/company/terms.html", "url"=>"", "language"=>"english", "iso-639-1"=>"en", "iso-639-2"=>"eng", "iso-639-3"=>"eng", "ethnologue"=>"http://www.ethnologue.com/show_language.asp?code=eng", "native-speakers"=>"309-400 million", "wikipedia"=>"http://en.wikipedia.org/wiki/English_language"}

# Entity Extraction

results = AlchemyAPI.search(:entity_extraction, text: text)
 => [{"type"=>"Person", "relevance"=>"0.948322", "count"=>"1", "text"=>"Donald Trump", "disambiguated"=>{"subType"=>["AwardNominee", "AwardWinner", "Celebrity", "CompanyFounder", "TVPersonality", "TVProducer", "FilmActor", "TVActor"], "name"=>"Donald Trump", "website"=>"http://www.trumponline.com/", "dbpedia"=>"http://dbpedia.org/resource/Donald_Trump", "freebase"=>"http://rdf.freebase.com/ns/m.0cqt90", "opencyc"=>"http://sw.opencyc.org/concept/Mx4rv0ncIZwpEbGdrcN5Y29ycA", "yago"=>"http://yago-knowledge.org/resource/Donald_Trump"}}, {"type"=>"FieldTerminology", "relevance"=>"0.89276", "count"=>"1", "text"=>"diplomatic relations"}, {"type"=>"Country", "relevance"=>"0.802341", "count"=>"2", "text"=>"United States", "disambiguated"=>{"subType"=>["Location", "Region", "AdministrativeDivision", "GovernmentalJurisdiction", "FilmEditor"], "name"=>"United States", "website"=>"http://www.usa.gov/", "dbpedia"=>"http://dbpedia.org/resource/United_States", "freebase"=>"http://rdf.freebase.com/ns/m.09c7w0", "ciaFactbook"=>"http://www4.wiwiss.fu-berlin.de/factbook/resource/United_States", "opencyc"=>"http://sw.opencyc.org/concept/Mx4rvVikKpwpEbGdrcN5Y29ycA", "yago"=>"http://yago-knowledge.org/resource/United_States"}}, {"type"=>"JobTitle", "relevance"=>"0.727315", "count"=>"1", "text"=>"president-elect"}, {"type"=>"Country", "relevance"=>"0.6751", "count"=>"2", "text"=>"Taiwan", "disambiguated"=>{"subType"=>["Location", "GeographicFeature", "Island"], "name"=>"Taiwan", "geo"=>"23.766666666666666 121.0", "dbpedia"=>"http://dbpedia.org/resource/Taiwan", "freebase"=>"http://rdf.freebase.com/ns/m.06f32", "ciaFactbook"=>"http://www4.wiwiss.fu-berlin.de/factbook/resource/Taiwan", "yago"=>"http://yago-knowledge.org/resource/Taiwan"}}, {"type"=>"JobTitle", "relevance"=>"0.53834", "count"=>"1", "text"=>"president"}, {"type"=>"JobTitle", "relevance"=>"0.382965", "count"=>"1", "text"=>"official"}]

# Concept Tagging

results = AlchemyAPI.search(:concept_tagging, text: text)
 => [{"text"=>"United States", "relevance"=>"0.946684", "website"=>"http://www.usa.gov/", "dbpedia"=>"http://dbpedia.org/resource/United_States", "ciaFactbook"=>"http://www4.wiwiss.fu-berlin.de/factbook/resource/United_States", "freebase"=>"http://rdf.freebase.com/ns/m.09c7w0", "opencyc"=>"http://sw.opencyc.org/concept/Mx4rvVikKpwpEbGdrcN5Y29ycA", "yago"=>"http://yago-knowledge.org/resource/United_States"}, {"text"=>"Republic of China", "relevance"=>"0.852894", "geo"=>"22.95 120.2", "dbpedia"=>"http://dbpedia.org/resource/Republic_of_China", "yago"=>"http://yago-knowledge.org/resource/Republic_of_China"}, {"text"=>"Pacific Ocean", "relevance"=>"0.538995", "geo"=>"-52.35 -68.35", "dbpedia"=>"http://dbpedia.org/resource/Pacific_Ocean", "ciaFactbook"=>"http://www4.wiwiss.fu-berlin.de/factbook/resource/Pacific_Ocean", "freebase"=>"http://rdf.freebase.com/ns/m.05rgl", "opencyc"=>"http://sw.opencyc.org/concept/Mx4rvVjgu5wpEbGdrcN5Y29ycA"}, {"text"=>"President of the United States", "relevance"=>"0.534273", "website"=>"http://www.whitehouse.gov/administration/president_obama/", "dbpedia"=>"http://dbpedia.org/resource/President_of_the_United_States", "freebase"=>"http://rdf.freebase.com/ns/m.060d2", "opencyc"=>"http://sw.opencyc.org/concept/Mx4rwQBS0ZwpEbGdrcN5Y29ycA", "yago"=>"http://yago-knowledge.org/resource/President_of_the_United_States"}, {"text"=>"Republic", "relevance"=>"0.526073", "dbpedia"=>"http://dbpedia.org/resource/Republic", "freebase"=>"http://rdf.freebase.com/ns/m.06cx9", "opencyc"=>"http://sw.opencyc.org/concept/Mx4rRh4l5m29EdaAAACgyZzFrg"}, {"text"=>"2003 invasion of Iraq", "relevance"=>"0.524927", "dbpedia"=>"http://dbpedia.org/resource/2003_invasion_of_Iraq", "freebase"=>"http://rdf.freebase.com/ns/m.01cpp0", "yago"=>"http://yago-knowledge.org/resource/2003_invasion_of_Iraq"}, {"text"=>"War of 1812", "relevance"=>"0.513632", "dbpedia"=>"http://dbpedia.org/resource/War_of_1812", "freebase"=>"http://rdf.freebase.com/ns/m.086m1", "yago"=>"http://yago-knowledge.org/resource/War_of_1812"}, {"text"=>"Franklin D. Roosevelt", "relevance"=>"0.501478", "dbpedia"=>"http://dbpedia.org/resource/Franklin_D._Roosevelt", "freebase"=>"http://rdf.freebase.com/ns/m.02yy8", "opencyc"=>"http://sw.opencyc.org/concept/Mx4rwPzUDpwpEbGdrcN5Y29ycA", "yago"=>"http://yago-knowledge.org/resource/Franklin_D._Roosevelt", "musicBrainz"=>"http://zitgist.com/music/artist/afac40dc-7788-4da7-9229-61d660e77dd3"}]

# Language Support

Afrikaans ISO-639-3: afr
Albanian  ISO-639-3: sqi
Amharic ISO-639-3: amh
Amuzgo Guerrero ISO-639-3: amu
Arabic  ISO-639-3: ara
Armenian  ISO-639-3: hye
Azerbaijani ISO-639-3: aze
Basque  ISO-639-3: eus
Breton  ISO-639-3: bre
Bulgarian ISO-639-3: bul
Catalan ISO-639-3: cat
Cebuano ISO-639-3: ceb
Central K'iche' ISO-639-3: qut
Central Mam ISO-639-3: mvc
Chamorro  ISO-639-3: cha
Cherokee  ISO-639-3: chr
Chinese ISO-639-3: zho
Comaltepec Chinantec  ISO-639-3: cco
Croatian  ISO-639-3: hrv
Cubulco Achi' ISO-639-3: acc
Czech ISO-639-3: ces
Dakota  ISO-639-3: dak
Danish  ISO-639-3: dan
Dutch ISO-639-3: nld
English ISO-639-3: eng
Esperanto ISO-639-3: epo
Estonian  ISO-639-3: est
Faroese ISO-639-3: fao
Fijian  ISO-639-3: fij
Finnish ISO-639-3: fin
French  ISO-639-3: fra
Fulfulde Adamawa  ISO-639-3: fub
Georgian  ISO-639-3: kat
German  ISO-639-3: deu
Greek ISO-639-3: ell
Guerrero Nahuatl  ISO-639-3: ngu
Gujarti ISO-639-3: guj
Haitian Creole  ISO-639-3: hat
Hausa ISO-639-3: hau
Hawaiian  ISO-639-3: haw
Hebrew  ISO-639-3: heb
Hiligaynon  ISO-639-3: hil
Hindi ISO-639-3: hin
Hungarian ISO-639-3: hun
Icelandic ISO-639-3: isl
Indonesian  ISO-639-3: ind
Irish ISO-639-3: gle
Italian ISO-639-3: ita
Jacalteco ISO-639-3: jac
Japanese  ISO-639-3: jpn
Kabyle  ISO-639-3: kab
Kaqchikel ISO-639-3: cak
Kirghiz ISO-639-3: kir
Kisongye  ISO-639-3: sop
Korean  ISO-639-3: kor
Latin ISO-639-3: lat
Latvian ISO-639-3: lav
Lithuanian  ISO-639-3: lit
Low Saxon ISO-639-3: nds
Macedonian  ISO-639-3: mkd
Malay ISO-639-3: msa
Maltese ISO-639-3: mlt
Maori ISO-639-3: mri
Micmac  ISO-639-3: mic
Mòoré ISO-639-3: mos
Ndebele ISO-639-3: nde
Nepali  ISO-639-3: nep
Norwegian ISO-639-3: nor
Ojibwa  ISO-639-3: oji
Pashto  ISO-639-3: pus
Persian ISO-639-3: fas
Polish  ISO-639-3: pol
Portuguese  ISO-639-3: por
Q'eqchi'  ISO-639-3: kek
Romanian  ISO-639-3: ron
Romani  ISO-639-3: rom
Russian ISO-639-3: rus
Serbian ISO-639-3: srp
Shona ISO-639-3: sna
Shuar ISO-639-3: jiv
Slovak  ISO-639-3: slk
Slovenian ISO-639-3: slv
Spanish ISO-639-3: spa
Swahili ISO-639-3: swa
Swedish ISO-639-3: swe
Tagalog ISO-639-3: tgl
Thai  ISO-639-3: tha
Todos Santos Cuchumatan Mám ISO-639-3: mvj
Turkish ISO-639-3: tur
Ukrainian ISO-639-3: ukr
Urdu  ISO-639-3: urd
Uspanteco ISO-639-3: usp
Vietnamese  ISO-639-3: vie
Welsh ISO-639-3: cym
Wolof ISO-639-3: wol
Xhosa ISO-639-3: xho
Zarma ISO-639-3: ssa

