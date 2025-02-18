# GeneLab Amplicon Sequencing Workflow Information and Usage Instructions

## General Workflow Info

### Implementation Tools

The current GeneLab (Illumina) Amplicon Sequencing data processing pipeline, [GL-DPPD-7104-B.md](https://github.com/nasa/GeneLab_Data_Processing/blob/master/Amplicon/Illumina/Pipeline_GL-DPPD-7104_Versions/GL-DPPD-7104-B.md), is implemented as a [Nextflow](https://nextflow.io/) DSL2 workflow and utilizes [Docker](https://www.docker.com/) or [Singularity](https://docs.sylabs.io/guides/latest/user-guide/) containers or [conda](https://docs.conda.io/en/latest/) environments to install/run all tools. This workflow is run using the command line interface (CLI) of any unix-based system.  While knowledge of creating workflows in nextflow is not required to run the workflow as is, [the Nextflow documentation](https://nextflow.io/docs/latest/index.html) is a useful resource for users who want to modify and/or extend this workflow.   

> *Workflow changes are documented in the [CHANGELOG](CHANGELOG.md).* 

<br>

## Utilizing the Workflow

1. [Install Nextflow and Singularity](#1-install-nextflow-and-singularity)  
   1a. [Install Nextflow](#1a-install-nextflow)  
   1b. [Install Singularity](#1b-install-singularity)  

2. [Download the workflow files](#2-download-the-workflow-files)  

3. [Fetch Singularity Images](#3-fetch-singularity-images)  

4. [Run the workflow directly with nextflow](#4-run-the-workflow-directly-with-nextflow)  
   4a. [Approach 1: Run slurm jobs in singularity containers with OSD accession as input](#4a-approach-1-run-slurm-jobs-in-singularity-containers-with-osd-accession-as-input)   
   4b. [Approach 2: Run slurm jobs in singularity containers with a csv file as input](#4b-approach-2-run-slurm-jobs-in-singularity-containers-with-a-csv-file-as-input)  
   4c. [Approach 3: Run jobs locally in conda environments and specify the path to one or more existing conda environments](#4c-approach-run-jobs-locally-in-conda-environments-and-specify-the-path-to-one-or-more-existing-conda-environments)  
   4d. [Modify parameters and cpu resources in the nextflow config file](#4d-modify-parameters-and-cpu-resources-in-the-nextflow-config-file)  

5. [Run the workflow indirectly using the python wrapper script](#5-run-the-workflow-indirectly-using-the-python-wrapper-script)  
   5a. [Approach 1: Use an OSD or Genelab acession as input](#5a-approach-1-use-an-osd-or-Genelab-acession-as-input)  
   5b. [Approach 2: Use a csv file as input to the workflow](#5b-approach-2-use-a-csv-file-as-input-to-the-workflow)  
   5c. [Approach 3: Use a csv file as input to the workflow and supply extra arguments to nextflow run](#5c-approach-3-use-a-csv-file-as-input-to-the-workflow-and-supply-extra-arguments-to-nextflow-run)  
   5d. [Approach 4: Just create an edited nextflow config file but dont run the workflow](#5d-approach-4-just-create-an-edited-nextflow-config-file-but-dont-run-the-workflow)  

6. [Workflow outputs](#6-workflow-outputs)  
   6a. [Main outputs](#6a-main-outputs)  
   6b. [Resource logs](#6b-resource-logs)  

7. [Post Processing](#6-post-processing) 

<br>

---

### 1. Install Nextflow and Singularity

#### 1a. Install Nextflow

Nextflow can be installed either through [Anaconda](https://anaconda.org/bioconda/nextflow) or as documented on the [Nextflow documentation page](https://www.nextflow.io/docs/latest/getstarted.html).

> Note: If you want to install Anaconda, we recommend installing a Miniconda, Python3 version appropriate for your system, as instructed by [Happy Belly Bioinformatics](https://astrobiomike.github.io/unix/conda-intro#getting-and-installing-conda).  
> 
> Once conda is installed on your system, you can install the latest version of Nextflow by running the following commands:
> 
> ```bash
> conda install -c bioconda nextflow
> nextflow self-update
> ```

<br>

#### 1b. Install Singularity

Singularity is a container platform that allows usage of containerized software. This enables the GeneLab workflow to retrieve and use all software required for processing without the need to install the software directly on the user's system.

We recommend installing Singularity on a system wide level as per the associated [documentation](https://docs.sylabs.io/guides/3.10/admin-guide/admin_quickstart.html).

> Note: Singularity is also available through [Anaconda](https://anaconda.org/conda-forge/singularity).

<br>

---

### 2. Download the workflow files

All files required for utilizing the NF_XXX GeneLab workflow for processing amplicon illumina data are in the [workflow_code](workflow_code) directory. To get a copy of latest *NF_XXX* version on to your system, the code can be downloaded as a zip file from the release page then unzipped after downloading by running the following commands: 

```bash
wget https://github.com/nasa/GeneLab_Data_Processing/releases/download/NF_AmpIllumina/NF_AmpIllumina.zip
unzip NF_AmpIllumina.zip &&  cd NF_XXX-X_X.X.X
```

<br>

---

### 3. Fetch Singularity Images

Although Nextflow can fetch Singularity images from a url, doing so may cause issues as detailed [here](https://github.com/nextflow-io/nextflow/issues/1210).

To avoid this issue, run the following command to fetch the Singularity images prior to running the NF_AmpIllumina workflow:

> Note: This command should be run in the location containing the `NF_AMPIllumina` directory that was downloaded in [step 2](#2-download-the-workflow-files) above.  

```bash
bash ./bin/prepull_singularity.sh nextflow.config
```

Once complete, a `singularity` folder containing the Singularity images will be created. Run the following command to export this folder as a Nextflow configuration environment variable to ensure Nextflow can locate the fetched images:

```bash
export NXF_SINGULARITY_CACHEDIR=$(pwd)/singularity
```

<br>

---

### 4. Run the workflow directly with nextflow

For options and detailed help on how to run the workflow, run the following command:

```bash
nextflow run main.nf --help
```

> Note: Nextflow commands use both single hyphen arguments (e.g. -help) that denote general nextflow arguments and double hyphen arguments (e.g. --input_file) that denote workflow specific parameters.  Take care to use the proper number of hyphens for each argument.
> Please Note: This workflow assumes that all your raw reads end with the same suffix. If they don't, please modify your input read filenames to have the same suffix as shown in [SE_file.csv](workflow_code/SE_file.csv) and [PE_file.csv](workflow_code/PE_file.csv).
<br>

#### 4a. Approach 1: Run slurm jobs in singularity containers with OSD or GLDS accession as input

```bash
nextflow run main.nf -resume -profile slurm,singularity --accession GLDS-487 --target_region 16S
```

<br>

#### 4b. Approach 2: Run slurm jobs in singularity containers with a csv file as input

```bash
nextflow run main.nf -resume -profile slurm,singularity  --input_file PE_file.csv --target_region 16S --F_primer AGAGTTTGATCCTGGCTCAG --R_primer CTGCCTCCCGTAGGAGT 
```

<br>

#### 4c. Approach 3: Run jobs locally in conda environments and specify the path to one or more existing conda environment(s)

```bash
nextflow run main.nf -resume -profile conda --input_file SE_file.csv --target_region 16S --F_primer AGAGTTTGATCCTGGCTCAG --R_primer CTGCCTCCCGTAGGAGT --conda.qc <path/to/existing/conda/environment>
```

<br>

**Required Parameters For All Approaches:**

* `-run main.nf` - Instructs nextflow to run the NF_XXX workflow 
* `-resume` - Resumes  workflow execution using previously cached results
* `-profile` – Specifies the configuration profile(s) to load, `singularity` instructs nextflow to setup and use singularity for all software called in the workflow
* `--target_region` – Specifies the amplicon target region to be analyzed, 16S, 18S or ITS.

  *Required only if you would like to pull and process data directly from OSDR*

* `--accession` – A Genelab / OSD accession number e.g. GLDS-487.

*Required only if --accession is not passed as an argument*

* `--input_file` –  A 4-column (single-end) or 5-column (paired-end) input csv file with the following headers (sample_id, forward, [reverse,] paired, groups). Please see the sample [SE_file.csv](workflow_code/SE_file.csv) and [PE_file.csv](workflow_code/PE_file.csv) in this repository for examples on how to format this file.

* `--F_primer` – Forward primer sequence.

* `--R_primer` – Reverse primer sequence.

> See `nextflow run -h` and [Nextflow's CLI run command documentation](https://nextflow.io/docs/latest/cli.html#run) for more options and details on how to run nextflow.

<br>

#### 4d. Modify parameters and cpu resources in the nextflow config file

Additionally, the parameters and workflow resources can be directly specified in the nextflow.config file. For detailed instructions on how to modify and set parameters in the nextflow.config file, please see the [documentation here](https://www.nextflow.io/docs/latest/config.html).

Once you've downloaded the workflow template, you can modify the parameters in the `params` scope and cpus/memory requirements in the `process` scope in your downloaded version of the [nextflow.config](workflow_code/nextflow.config) file as needed in order to match your dataset and system setup. For example, you can directly set the the full paths to available conda environments in the `conda` scope within the `params`  scope. Additionally, if necessary, you'll need to modify each variable in the  [nextflow.config](workflow_code/nextflow.config) file to be consistent with the study you want to process and the machine you're using.

<br>

---

### 5. Run the workflow indirectly using the python wrapper script

For options and detailed help on how to run the workflow using the script, run the following command:

```bash
python run_workflow.py
```

#### 5a. Approach 1: Use an OSD or Genelab acession as input

```bash
python run_workflow.py --run --target-region 16S --accession GLDS-487 --profile slurm,singularity 
```

#### 5b. Approach 2: Use a csv file as input to the workflow

```bash
python run_workflow.py --run --target-region 16S --input-file PE_file.csv --F-primer AGAGTTTGATCCTGGCTCAG --R-primer CTGCCTCCCGTAGGAGT --profile singularity 
```

#### 5c. Approach 3: Use a csv file as input to the workflow and supply extra arguments to nextflow run 

Here were want to monitor our jobs with nextflow tower.

```bash
export TOWER_ACCESS_TOKEN=<ACCESS TOKEN>
export TOWER_WORKSPACE_ID=<WORKSPACE ID>
python run_workflow.py --run --target-region 16S --input-file PE_file.csv --F-primer AGAGTTTGATCCTGGCTCAG --R-primer CTGCCTCCCGTAGGAGT --profile slurm,conda --extra 'with-tower'
```

#### 5d. Aproach 4: Just create an edited nextflow config file but dont run the workflow

```bash
python run_workflow.py --target-region 16S --accession GLDS-487 --profile slurm,singularity
```

> Note: When using the wrapper script, all outputs generated by the workflow will be in a directory specified by the `--output-dir` parameter. This will be the parent directory `..` by default.

<br>

---

### 6. Workflow outputs

#### 6a. Main outputs

The outputs from this pipeline are documented in the [GL-DPPD-7104-B](../../Pipeline_GL-DPPD-7104_Versions/GL-DPPD-7104-B.md) processing protocol.

#### 6b. Resource logs

Standard nextflow resource usage logs are also produced as follows:

- Output:
  - Resource_Usage/execution_report_{timestamp}.html (an html report that includes metrics about the workflow execution including computational resources and exact workflow process commands)
  - Resource_Usage/execution_timeline_{timestamp}.html (an html timeline for all processes executed in the workflow)
  - Resource_Usage/execution_trace_{timestamp}.txt (an execution tracing file that contains information about each process executed in the workflow, including: submission time, start time, completion time, cpu and memory used, machine-readable output)

> Further details about these logs can also found within [this Nextflow documentation page](https://www.nextflow.io/docs/latest/tracing.html#execution-report).

<br>

---

### 7. Post Processing

For options and detailed help on how to run the post-processing workflow, run the following command:

```bash
nextflow run post_processing.nf --help
```

To generate a README file, a protocols file, a md5sums table and a file association table after running the processing workflow sucessfully, modify and set the parameters in [post_processing.config](workflow_code/post_processing.config) then run the following command:

```bash
nextflow -C post_processing.config run post_processing.nf -resume -profile slurm,singularity
``` 

The outputs of the run will be in a directory called `Post_Processing` by default and they are as follows:
 - Post_processing/FastQC_Outputs/filtered_multiqc_GLAmpSeq_report.zip (Filtered sequence multiqc report with paths purged) 
 - Post_processing/FastQC_Outputs/raw_multiqc_GLAmpSeq_report.zip (Raw sequence multiqc report with paths purged)
 - Post_processing/<GLDS_accession>_-associated-file-names.tsv (File association table for curation)
 - Post_processing/<GLDS_accession>_amplicon-validation.log (Automatic verification and validation log file)
 - Post_processing/processed_md5sum_GLAmpSeq.tsv (md5sums for the files to be released on OSDR)
 - Post_processing/processing_info_GLAmpSeq.zip  (Zip file containing all files used to run the workflow and required logs with paths purged) 
 - Post_processing/protocol.txt  (File describing the methods used by the workflow)
 - Post_processing/README_GLAmpSeq.txt (README file listing and describing the outputs of the workflow)


<br>

---

## Licenses

The software for the Amplicon Seq pipelines is released under the [NASA Open Source Agreement (NOSA) Version 1.3](LICENSE/Amplicon_and_Metagenomics_NOSA_License.pdf).


### 3rd Party Software Licenses

Licenses for the 3rd party open source software utilized in the Amplicon Seq pipelines can be found in the [3rd_Party_Licenses directory](3rd_Party_Licenses/GL_Amplicon_3rd_Party_Software.md). 

<br>

---

## Notices

Copyright © 2021 United States Government as represented by the Administrator of the National Aeronautics and Space Administration.  All Rights Reserved.

### Disclaimers

No Warranty: THE SUBJECT SOFTWARE IS PROVIDED "AS IS" WITHOUT ANY WARRANTY OF ANY KIND, EITHER EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, ANY WARRANTY THAT THE SUBJECT SOFTWARE WILL CONFORM TO SPECIFICATIONS, ANY IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR FREEDOM FROM INFRINGEMENT, ANY WARRANTY THAT THE SUBJECT SOFTWARE WILL BE ERROR FREE, OR ANY WARRANTY THAT DOCUMENTATION, IF PROVIDED, WILL CONFORM TO THE SUBJECT SOFTWARE. THIS AGREEMENT DOES NOT, IN ANY MANNER, CONSTITUTE AN ENDORSEMENT BY GOVERNMENT AGENCY OR ANY PRIOR RECIPIENT OF ANY RESULTS, RESULTING DESIGNS, HARDWARE, SOFTWARE PRODUCTS OR ANY OTHER APPLICATIONS RESULTING FROM USE OF THE SUBJECT SOFTWARE.  FURTHER, GOVERNMENT AGENCY DISCLAIMS ALL WARRANTIES AND LIABILITIES REGARDING THIRD-PARTY SOFTWARE, IF PRESENT IN THE ORIGINAL SOFTWARE, AND DISTRIBUTES IT "AS IS."

Waiver and Indemnity:  RECIPIENT AGREES TO WAIVE ANY AND ALL CLAIMS AGAINST THE UNITED STATES GOVERNMENT, ITS CONTRACTORS AND SUBCONTRACTORS, AS WELL AS ANY PRIOR RECIPIENT.  IF RECIPIENT'S USE OF THE SUBJECT SOFTWARE RESULTS IN ANY LIABILITIES, DEMANDS, DAMAGES, EXPENSES OR LOSSES ARISING FROM SUCH USE, INCLUDING ANY DAMAGES FROM PRODUCTS BASED ON, OR RESULTING FROM, RECIPIENT'S USE OF THE SUBJECT SOFTWARE, RECIPIENT SHALL INDEMNIFY AND HOLD HARMLESS THE UNITED STATES GOVERNMENT, ITS CONTRACTORS AND SUBCONTRACTORS, AS WELL AS ANY PRIOR RECIPIENT, TO THE EXTENT PERMITTED BY LAW.  RECIPIENT'S SOLE REMEDY FOR ANY SUCH MATTER SHALL BE THE IMMEDIATE, UNILATERAL TERMINATION OF THIS AGREEMENT.

