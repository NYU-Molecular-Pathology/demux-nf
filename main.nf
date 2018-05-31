// check some params from configs
if(params.runID == null){
    log.warn "runID ID is not set, use '--runID runID'"
}

def run_dir
if(params.run_dir == null){
    run_dir = "${params.sequencer_dir}/${params.runID}"
    log.warn "Run dir not provided, attempting to use default location: ${run_dir}"
} else {
    run_dir = "${params.run_dir}"
}
run_dir = new File(run_dir).getCanonicalPath()

def run_dir_obj = new File("${run_dir}")
if( !run_dir_obj.exists() ){
    log.error "Run dir does not exist: ${run_dir}"
    exit 1
}
params.basecalls_dir = "${run_dir}/Data/Intensities/BaseCalls"

if(params.samplesheet == null){
    log.error "No samplesheet file provided; use '--samplesheet SampleSheet.csv'"
    exit 1
}

log.info "~~~~~~~ Demultiplexing Pipeline ~~~~~~~"
log.info "* Run ID:          ${params.runID}"
log.info "* Sequencer dir:   ${params.sequencer_dir}"
log.info "* Run dir:         ${run_dir}"
log.info "* Basecalls dir:   ${params.basecalls_dir}"
log.info "* Output dir:      ${params.output_dir} "
log.info "* Samplesheet:     ${params.samplesheet}"

Channel.fromPath( params.samplesheet ).set { samplesheet_input }
Channel.from( "${run_dir}" ).into { run_dir_ch; run_dir_ch2 } // dont stage run dir for safety reasons, just pass the path
Channel.fromPath( params.report_template_dir ).set { report_template_dir }

process validate_run_completion {
    tag "${run_dir}"
    executor "local"
    publishDir "${params.output_dir}/", mode: 'copy', overwrite: true

    input:
    val(run_dir) from run_dir_ch

    output:
    file("RTAComplete.txt") into run_RTAComplete_txt
    file("RunCompletionStatus.xml") into run_CompletionStatus_xml
    file("RunParameters.xml") into run_params_xml
    val('') into done_validate_run_completion

    script:
    """
    cp ${run_dir}/RTAComplete.txt .
    cp ${run_dir}/RunCompletionStatus.xml .
    cp ${run_dir}/RunParameters.xml .
    """

}

process validate_samplesheet {
    tag "${samplesheet}"
    executor "local"

    input:
    file(samplesheet) from samplesheet_input

    output:
    file("${samplesheet}") into validated_samplesheet
    val('') into done_validate_samplesheet

    script:
    """
    validate-samplesheet.py "${samplesheet}"
    """
}

process copy_samplesheet {
    tag "${samplesheet}"
    executor "local"
    publishDir "${params.output_dir}/", mode: 'copy', overwrite: true

    input:
    file(samplesheet) name "input_sheet.csv" from validated_samplesheet

    output:
    file("SampleSheet.csv") into (samplesheet_copy, samplesheet_copy2)
    val('') into done_copy_samplesheet

    script:
    """
    cp "input_sheet.csv" SampleSheet.csv
    """

}


process convert_run_params{
    tag "${run_params_xml_file}"
    publishDir "${params.output_dir}/", mode: 'copy', overwrite: true
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
    tag "${run_dir_path}"
    publishDir "${params.output_dir}/", mode: 'copy', overwrite: true

    input:
    set file(samplesheet), val(run_dir_path) from samplesheet_copy.combine(run_dir_ch2)

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
    --sample-sheet ${samplesheet} \
    --runfolder-dir ${run_dir_path} \
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
    publishDir "${params.output_dir}/fastqc", mode: 'copy', overwrite: true

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
    publishDir "${params.output_dir}/multiqc", mode: 'move', overwrite: true
    executor "local"

    input:
    // val(items) from all_done1.collect() // force it to wait for all steps to finish
    // file(output_dir) from Channel.fromPath("${params.output_dir}")
    file(all_fastqc_zips: "*") from fastqc_zips.collect()

    output:
    file "multiqc_report.html" into multiqc_report_html
    file "multiqc_data"

    script:
    """
    multiqc .
    """
}

process demultiplexing_report {
    tag "${template_dir}"
    executor "local"
    publishDir "${params.output_dir}/demultiplexing-report", mode: 'move', overwrite: true
    stageInMode "copy"

    input:
    val(items) from all_done2.collect() // force it to wait for all steps to finish
    set file(template_dir), file(demultiplex_stats) from report_template_dir.combine(demultiplex_stats_html2)

    output:
    file("demultiplexing_report.html") into demultiplexing_report_html

    script:
    """
    mv ${demultiplex_stats} "${template_dir}/"
    compile_Rmd.R "${template_dir}/demultiplexing_report.Rmd"
    mv "${template_dir}/demultiplexing_report.html" .
    """
}


process collect_email_attachments {
    tag "${attachments}"
    publishDir "${params.output_dir}/email/attachments", mode: 'move', overwrite: true
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
        Run directory     : ${params.run_dir}
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
    def subject = "[${params.workflow_label}] ${status}: ${params.runID}"
    def email_subject = new File("${params.output_dir}/email/subject.txt")
    email_subject.write "${subject}"
    def email_body = new File("${params.output_dir}/email/body.txt")
    email_body.write "${msg}".stripIndent()
}
