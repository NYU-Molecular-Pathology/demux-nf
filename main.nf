// ~~~~~ CHECK CONFIGS ~~~~~ //
params.configFile = "config.json"
params.outputDir = new File("output").getCanonicalPath()
params.runID = null // "180131_NB501073_0032_AHT5F3BGX3"
params.runDir = null
params.samplesheet = null

// load the JSON config, if present
import groovy.json.JsonSlurper
def jsonSlurper = new JsonSlurper()
def demuxConfig
def demuxConfigFile_obj = new File("${params.configFile}")
if ( demuxConfigFile_obj.exists() ) {
    log.info("Loading configs from ${params.configFile}")
    String demuxConfigJSON = demuxConfigFile_obj.text
    demuxConfig = jsonSlurper.parseText(demuxConfigJSON)
}

// check for Run ID
// 0. use CLI passed arg
// 1. check for config.json values
// 2. look for 'runID.txt' in current dir, get runID from that
// 3. use the name of the current directory
def default_runID_file = "runID.txt"
def default_runID_obj = new File("${default_runID_file}")
def current_dir = System.getProperty("user.dir")
def current_dirname = new File("${current_dir}").getName()
def runID
if(params.runID == null){
    if ( demuxConfig && demuxConfig.containsKey("runID") && demuxConfig.runID != null ) {
        runID = "${demuxConfig.runID}"
    } else if( default_runID_obj.exists() ) {
        runID = default_runID_obj.readLines()[0]
    } else {
        runID = "${current_dirname}"
    }
} else {
    runID = "${params.runID}"
}

// check for a sequencing run directory was passed
// otherwise:
// 0. use CLI passed dir
// 1. check for config.json values
// 2. look for 'runDir' symlink or dir in current directory
// 3. try to locate the directory based on the runID + default location
def default_runDir = "runDir"
def default_runDir_obj = new File("${default_runDir}")
def default_runDir_path
def system_runDir_path = "${params.sequencer_dir}/${runID}"
def system_runDir_obj = new File("${system_runDir_path}")
def runDir
if( params.runDir == null ){
    if ( demuxConfig && demuxConfig.containsKey("runDir") && demuxConfig.runDir != null  ) {
        runDir = demuxConfig.runDir
    } else if( default_runDir_obj.exists() ){
        // check if 'runDir' exists in local dir & is valid symlink; resolve symlink
        runDir = default_runDir_obj.getCanonicalPath()
    } else if( system_runDir_obj.exists() ){
            // use found path
            runDir = system_runDir_path
        }
} else {
    runDir = "${params.runDir}"
}

// make sure the run dir really does exist
runDir = new File(runDir).getCanonicalPath()
def runDir_obj = new File("${runDir}")
if( !runDir_obj.exists() ){
    log.error "Run dir does not exist: ${runDir}"
    exit 1
}

// make sure the Basecalls dir exists inside the run dir
def basecallsDir = "${runDir}/Data/Intensities/BaseCalls"
def basecallsDir_obj = new File("${basecallsDir}")
if( ! basecallsDir_obj.exists() ){
    log.error("Basecalls dir does not exist: ${basecallsDir}")
    exit 1
}

// Check for samplesheet;
// 0. Use CLI passed samplesheet
// 1. check for config.json values
// 2. Check for SampleSheet.csv in current directory
def default_samplesheet = "SampleSheet.csv"
def default_samplesheet_obj = new File("${default_samplesheet}")
def default_samplesheet_path
def samplesheet
if(params.samplesheet == null){
    if ( demuxConfig && demuxConfig.containsKey("samplesheet") && demuxConfig.samplesheet != null ) {
        samplesheet = demuxConfig.samplesheet
    } else if( default_samplesheet_obj.exists() ){
        samplesheet = default_samplesheet_obj.getCanonicalPath()
    } else {
        log.error("No samplesheet found, please provide one with '--samplesheet'")
        exit 1
    }
} else {
    samplesheet = params.samplesheet
}


// ~~~~~ START WORKFLOW ~~~~~ //
log.info "~~~~~~~ Demultiplexing Pipeline ~~~~~~~"
log.info "* Run ID:          ${runID}"
log.info "* Sequencer dir:   ${params.sequencer_dir}"
log.info "* Run dir:         ${runDir}"
log.info "* Output dir:      ${params.outputDir} "
log.info "* Samplesheet:     ${samplesheet}"
log.info "* Launch dir:      ${workflow.launchDir}"
log.info "* Work dir:        ${workflow.workDir}"

Channel.fromPath( "${samplesheet}" ).set { samplesheet_input }
Channel.from( "${runDir}" ).into { runDir_ch; runDir_ch2 } // dont stage run dir for safety reasons, just pass the path
Channel.fromPath( params.report_template_dir ).set { report_template_dir }

process validate_run_completion {
    tag "${runDir}"
    executor "local"
    publishDir "${params.outputDir}/", mode: 'copy', overwrite: true

    input:
    val(runDir) from runDir_ch

    output:
    file("RTAComplete.txt") into run_RTAComplete_txt
    file("RunCompletionStatus.xml") into run_CompletionStatus_xml
    file("RunParameters.xml") into run_params_xml
    val('') into done_validate_run_completion

    script:
    """
    cp ${runDir}/RTAComplete.txt .
    cp ${runDir}/RunCompletionStatus.xml .
    cp ${runDir}/RunParameters.xml .
    """

}

process validate_samplesheet {
    tag "${samplesheetFile}"
    executor "local"

    input:
    file(samplesheetFile) from samplesheet_input

    output:
    file("${samplesheetFile}") into validated_samplesheet
    val('') into done_validate_samplesheet

    script:
    """
    validate-samplesheet.py "${samplesheetFile}"
    """
}

process copy_samplesheet {
    tag "${samplesheetFile}"
    executor "local"
    publishDir "${params.outputDir}/", mode: 'copy', overwrite: true

    input:
    file(samplesheetFile) name "input_sheet.csv" from validated_samplesheet

    output:
    file("SampleSheet.csv") into (samplesheet_copy, samplesheet_copy2)
    file("${runID}-SampleSheet.csv")
    val('') into done_copy_samplesheet

    script:
    output_samplesheet = "${runID}-SampleSheet.csv"
    """
    cp "input_sheet.csv" SampleSheet.csv
    cp "input_sheet.csv" "${output_samplesheet}"
    """

}


process convert_run_params{
    tag "${run_params_xml_file}"
    publishDir "${params.outputDir}/", mode: 'copy', overwrite: true
    executor "local"

    input:
    file(run_params_xml_file) from run_params_xml

    output:
    file("RunParameters.tsv") into run_params_tsv
    val('') into done_convert_run_params

    script:
    """
    RunParametersXML2tsv.py
    """
}

process bcl2fastq {
    tag "${runDir_path}"
    publishDir "${params.outputDir}/", mode: 'copy', overwrite: true

    input:
    set file(samplesheetFile), val(runDir_path) from samplesheet_copy.combine(runDir_ch2)

    output:
    file("Unaligned") into bcl2fastq_output
    file("Unaligned/Demultiplex_Stats.htm") into (demultiplex_stats_html, demultiplex_stats_html2)
    file("Unaligned/**.fastq.gz") into fastq_output
    file("Unaligned/*") into bcl2fastq_output_all
    val('') into done_bcl2fastq

    script:
    """
    nthreads="\${NSLOTS:-\${NTHREADS:-2}}"

    # 20% of threads for demult as per Illumina manual
    demult_threads="\$(( \$nthreads*2/10 ))"
    # at least 2 threads
    [ "\${demult_threads}" -lt "2" ] && demult_threads=2

    echo "[bcl2fastq]: \$(which bcl2fastq) running with \${nthreads} threads and \${demult_threads} demultiplexing threads"
    bcl2fastq --version

    bcl2fastq \
    --min-log-level WARNING \
    --fastq-compression-level 8 \
    --loading-threads 2 \
    --demultiplexing-threads \${demult_threads:-2} \
    --processing-threads \${nthreads:-2} \
    --writing-threads 2 \
    --sample-sheet ${samplesheetFile} \
    --runfolder-dir ${runDir_path} \
    --output-dir ./Unaligned \
    ${params.bcl2fastq_params}

    # create Demultiplex_Stats.htm
    cat Unaligned/Reports/html/*/all/all/all/laneBarcode.html | grep -v "href=" > Unaligned/Demultiplex_Stats.htm
    """
}

// filter out everything that is not a directory in order to find demultiplexing output
bcl2fastq_output_all.flatMap()
                    .filter { item ->
                        item.isDirectory()
                    }
                    .filter { item ->
                        def basename = item.getName()
                        basename != 'Stats' && basename != 'Reports'
                    }
                    .set { bcl2fastq_project_dirs }

// filter out 'Undetermined' fastq files
fastq_output.flatMap()
            .map{ item ->
                if (! "${item}".contains("Undetermined_")){
                    return item
                }
            }
            .set{ fastq_filtered }

process fastqc {
    tag "${fastq}"
    publishDir "${params.outputDir}/fastqc", mode: 'copy', overwrite: true

    input:
    file(fastq) from fastq_filtered

    output:
    file("${output_html}")
    file("${output_zip}") into fastqc_zips
    val("${output_html}") into done_fastqc

    script:
    output_html = "${fastq}".replaceFirst(/.fastq.gz$/, "_fastqc.html")
    output_zip = "${fastq}".replaceFirst(/.fastq.gz$/, "_fastqc.zip")
    """
    fastqc -o . "${fastq}"
    """
}

// ~~~~~~~~ REPORTING ~~~~~~~ //
done_validate_run_completion.concat(
    done_validate_samplesheet,
    done_copy_samplesheet,
    done_convert_run_params,
    done_bcl2fastq,
    done_fastqc
    ).into { all_done1; all_done2; all_done3 }

process multiqc {
    publishDir "${params.outputDir}/reports", mode: 'copy', overwrite: true
    executor "local"

    input:
    file(all_fastqc_zips: "*") from fastqc_zips.collect()

    output:
    file "${output_HTML}" into multiqc_report_html
    file "multiqc_data"
    file "multiqc_plots"

    script:
    output_HTML="${runID}-multiqc_report.html"
    output_pdf="${runID}-multiqc_report.pdf"
    """
    multiqc . --export
    mv multiqc_report.html "${output_HTML}"
    """
}

process demultiplexing_report {
    tag "${template_dir}"
    executor "local"
    publishDir "${params.outputDir}/reports", mode: 'copy', overwrite: true
    stageInMode "copy"

    input:
    val(items) from all_done2.collect() // force it to wait for all steps to finish
    set file(template_dir), file(demultiplex_stats) from report_template_dir.combine(demultiplex_stats_html2)

    output:
    file("${report_HTML}") into demultiplexing_report_html
    // file("${report_PDF}")

    script:
    report_RMD="${runID}-demultiplexing_report.Rmd"
    report_HTML="${runID}-demultiplexing_report.html"
    report_PDF="${runID}-demultiplexing_report.pdf"
    """
    # put the Demultiplex_Stats.htm file inside the report's dir
    mv ${demultiplex_stats} "${template_dir}/"

    # rename the report template file to match the desired output filename
    # cp "${template_dir}/demultiplexing_report.Rmd" "${template_dir}/${report_RMD}"

    # compile to HTML
    Rscript -e 'rmarkdown::render(input = "${template_dir}/demultiplexing_report.Rmd", output_format = "html_document", output_file = "${report_HTML}")'

    # compile to PDF
    # Rscript -e 'rmarkdown::render(input = "${template_dir}/demultiplexing_report.Rmd", output_format = "pdf_document", output_file = "${report_PDF}")'
    # ! LaTeX Error: File `ifluatex.sty' not found.

    # move the output files to the current directory
    mv "${template_dir}/${report_HTML}" .
    # mv "${template_dir}/${report_PDF}" .
    """
}


process collect_email_attachments {
    tag "${attachments}"
    publishDir "${params.outputDir}/email/attachments", mode: 'move', overwrite: true
    stageInMode "copy"
    executor "local"

    input:
    val(items) from all_done3.collect() // force it to wait for all steps to finish
    file(attachments: "*") from samplesheet_copy2.concat(demultiplex_stats_html, demultiplexing_report_html, run_params_tsv, run_RTAComplete_txt, multiqc_report_html ).collect()

    output:
    file(attachments) into email_attachments

    script:
    """
    echo "[collect_email_attachments] files to be attached: ${attachments}"
    """
}

// ~~~~~~~~~~~~~~~ PIPELINE COMPLETION EVENTS ~~~~~~~~~~~~~~~~~~~ //
workflow.onComplete {
    def status = "NA"
    if(workflow.success) {
        status = "SUCCESS"
    } else {
        status = "FAILED"
    }
    def msg = """
        Pipeline execution summary
        ---------------------------
        Success           : ${workflow.success}
        exit status       : ${workflow.exitStatus}
        Launch time       : ${workflow.start.format('dd-MMM-yyyy HH:mm:ss')}
        Ending time       : ${workflow.complete.format('dd-MMM-yyyy HH:mm:ss')} (duration: ${workflow.duration})
        Launch directory  : ${workflow.launchDir}
        Work directory    : ${workflow.workDir.toUriString()}
        Nextflow directory : ${workflow.projectDir}
        Run directory     : ${params.runDir}
        Script name       : ${workflow.scriptName ?: '-'}
        Script ID         : ${workflow.scriptId ?: '-'}
        Workflow session  : ${workflow.sessionId}
        Workflow repo     : ${workflow.repository ?: '-' }
        Workflow revision : ${workflow.repository ? "$workflow.revision ($workflow.commitId)" : '-'}
        Workflow profile  : ${workflow.profile ?: '-'}
        Workflow container: ${workflow.container ?: '-'}
        container engine  : ${workflow.containerEngine?:'-'}
        Nextflow run name : ${workflow.runName}
        Nextflow version  : ${workflow.nextflow.version}, build ${workflow.nextflow.build} (${workflow.nextflow.timestamp})
        The command used to launch the workflow was as follows:
        ${workflow.commandLine}
        --
        This email was sent by Nextflow
        cite doi:10.1038/nbt.3820
        http://nextflow.io
        """
        .stripIndent()
        // Total CPU-Hours   : ${workflow.stats.getComputeTimeString() ?: '-'}
    // save hard-copies of the custom email since it keeps breaking inside this pipeline
    def subject_line = "[${params.workflow_label}] ${status}: ${runID}"
    def email_subject = new File("${params.outputDir}/email/subject.txt")
    email_subject.write "${subject_line}"
    def email_body = new File("${params.outputDir}/email/body.txt")
    email_body.write "${msg}".stripIndent()

    sendMail {
      from "${params.email_to}"
      to "${params.email_from}"
      subject subject_line
      """
      ${msg}
      """.stripIndent()
    }
}
