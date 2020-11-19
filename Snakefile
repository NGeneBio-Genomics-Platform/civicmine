
import os

localrules: final_files

assert os.getenv('MODE') in ['full','test'], "Must set environmental variable MODE to full or test"

if os.getenv('MODE') == 'full':
	source_dir = os.getenv('BIOTEXT')
	assert source_dir and os.path.isdir(source_dir), "For full run, must set environmental variable BIOTEXT to directory with BIOTEXT BioC XML files"
	source_dir = source_dir.rstrip('/')
	work_dir = 'working'
elif os.getenv('MODE') == 'test':
	source_dir = 'test_data'
	work_dir = 'test_working'

kb_files = [ '%s/kb/%s' % (work_dir,f.replace('.bioc.xml','.tsv')) for f in os.listdir(source_dir) ]

final_files =  [ f"{work_dir}/{f}" for f in ['civicmine_unfiltered.tsv','civicmine_collated.tsv','civicmine_sentences.tsv'] ]

rule final_files:
	input: final_files

rule build_models:
	output: "models.flag"
	shell: "sh buildModels.sh && touch {output}"

rule get_biowordlists:
	output: f"{work_dir}/biowordlists.flag"
	shell: f"mkdir -p {work_dir}/biowordlists && zenodo_get -o {work_dir}/biowordlists https://doi.org/10.5281/zenodo.1286661 && touch {{output}}"

rule prepare_wordlist:
	input: f"{work_dir}/biowordlists.flag"
	output: f"{work_dir}/civicmine_terms.pickle"
	shell: f"python wordlistLoader.py --genes {work_dir}/biowordlists/terms_genes.tsv --cancers {work_dir}/biowordlists/terms_cancers.tsv --drugs {work_dir}/biowordlists/terms_drugs.tsv --conflicting {work_dir}/biowordlists/terms_conflicting.tsv --variants {work_dir}/biowordlists/terms_variants.tsv --wordlistPickle {{output}}"

rule parse_and_find_entities:
	input:
		biocxml=f"{source_dir}/{{f}}.bioc.xml",
		wordlist=f"{work_dir}/civicmine_terms.pickle"
	output: f"{work_dir}/sentenceData/{{f}}.json"
	shell: f"python findSentences.py --biocFile {{input.biocxml}} --filterTerms filterTerms.txt --wordlistPickle {{input.wordlist}} --variantStopwords stopwords_variants.txt --outSentencesFilename {{output}}"

rule apply_models_to_sentences:
	input:
		sentences=f"{work_dir}/sentenceData/{{f}}.json",
		wordlist=f"{work_dir}/civicmine_terms.pickle",
		biowordlists=f"{work_dir}/biowordlists.flag",
		models="models.flag"
	output:
		f"{work_dir}/kb/{{f}}.tsv"
	shell: f"python applyModelsToSentences.py --models models/Diagnostic.model,models/Predictive.model,models/Prognostic.model,models/Predisposing.model,models/AssociatedVariant.model --filterTerms filterTerms.txt --wordlistPickle {{input.wordlist}} --genes {work_dir}/biowordlists/terms_genes.tsv --cancerTypes {work_dir}/biowordlists/terms_cancers.tsv --drugs {work_dir}/biowordlists/terms_drugs.tsv --variants {work_dir}/biowordlists/terms_variants.tsv --sentenceFile {{input.sentences}} --outData {{output}}"

rule filter_and_collated:
	input: kb_files
	output:
		unfiltered=f"{work_dir}/civicmine_unfiltered.tsv",
		collated=f"{work_dir}/civicmine_collated.tsv",
		sentences=f"{work_dir}/civicmine_sentences.tsv",
	shell: f"python filterAndCollate.py --inData {work_dir}/kb/ --outUnfiltered {{output.unfiltered}} --outCollated {{output.collated}} --outSentences {{output.sentences}}"

