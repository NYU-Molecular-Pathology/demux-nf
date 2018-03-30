// params.project = "180131_NB501073_0032_AHT5F3BGX3"
// params.sequencer_dir = "/ifs/data/molecpathlab/quicksilver"
// params.output_dir = "${params.basecalls_dir}/Demultiplexing"
params.run_dir = "${params.sequencer_dir}/${params.project}"
params.basecalls_dir = "${params.run_dir}/Data/Intensities/BaseCalls"
params.output_dir = "${params.production_dir}/${params.project}"

params.report_template_dir = "nextseq-report"

log.info "~~~~~~~ Demultiplexing Pipeline ~~~~~~~"
log.info "* Project:         ${params.project}"
log.info "* Sequencer dir:   ${params.sequencer_dir}"
log.info "* Run dir:         ${params.run_dir}"
log.info "* Basecalls dir:   ${params.basecalls_dir}"
log.info "* Output dir:      ${params.output_dir} "
log.info "* Samplesheet:     ${params.samplesheet}"


Channel.fromPath( params.samplesheet ).set { samplesheet_input }
Channel.from( "${params.run_dir}" ).into { run_dir; run_dir2; run_dir3; run_dir4 } // dont stage run dir for safety reasons
Channel.fromPath( params.report_template_dir ).set { report_template_dir }

// process validate_RunParamsXML {
//     tag { "${run_dir}" }
//     executor "local"
//     publishDir "${params.output_dir}/", mode: 'copy', overwrite: true
//
//     input:
//     val(run_dir) from run_dir2
//
//     output:
//     file("RunParameters.xml") into run_params_xml
//
//     script:
//     """
//     cp ${run_dir}/RunParameters.xml .
//     """
//
// }

process validate_run_completion {
    tag { "${run_dir}" }
    executor "local"
    publishDir "${params.output_dir}/", mode: 'copy', overwrite: true

    input:
    val(run_dir) from run_dir2

    output:
    file("RTAComplete.txt") into run_RTAComplete_txt
    file("RunCompletionStatus.xml") into run_CompletionStatus_xml
    file("RunParameters.xml") into run_params_xml

    script:
    """
    cp ${run_dir}/RTAComplete.txt .
    cp ${run_dir}/RunCompletionStatus.xml .
    cp ${run_dir}/RunParameters.xml .
    """

}

process copy_samplesheet {
    tag { "${samplesheet}" }
    executor "local"
    publishDir "${params.output_dir}/", mode: 'copy', overwrite: true

    input:
    file(samplesheet) from samplesheet_input

    output:
    file("${samplesheet}")
    file("SampleSheet.csv") into samplesheet_copy
    file("SampleSheet.csv") into samplesheet_copy2

    script:
    """
    cp "${samplesheet}" SampleSheet.csv
    """

}

process bcl2fastq {
    tag { "${run_dir}" }
    publishDir "${params.output_dir}/", mode: 'copy', overwrite: true

    input:
    set file(samplesheet), val(run_dir) from samplesheet_copy.combine(run_dir)

    output:
    file("Unaligned") into bcl2fastq_output
    file("Unaligned/Demultiplex_Stats.htm") into demultiplex_stats_html
    file("Unaligned/Demultiplex_Stats.htm") into demultiplex_stats_html2
    file("Unaligned/**.fastq.gz") into fastq_output

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
    --runfolder-dir ${run_dir} \
    --output-dir ./Unaligned \
    ${params.bcl2fastq_params}

    # create Demultiplex_Stats.htm
    cat Unaligned/Reports/html/*/all/all/all/laneBarcode.html | grep -v "href=" > Unaligned/Demultiplex_Stats.htm
    """
}

// filter out 'Undetermined' fastq files
fastq_output.flatMap()
            .map{ item ->
                if (! "${item}".contains("Undetermined_")){
                    return item
                }
            }
            .set{ fastq_filtered }

process fastqc {
    tag { "${fastq}" }
    publishDir "${params.output_dir}/fastqc", mode: 'copy', overwrite: true

    input:
    file(fastq) from fastq_filtered

    output:
    file(output_html)
    file(output_zip)
    val(fastq) into fastqc_fastqs

    script:
    output_html = "${fastq}".replaceFirst(/.fastq.gz$/, "_fastqc.html")
    output_zip = "${fastq}".replaceFirst(/.fastq.gz$/, "_fastqc.zip")
    """
    fastqc -o . "${fastq}"
    """
}


// currently broken on phoenix ??
// process multiqc {
//     tag { "${output_dir}" }
//     publishDir "${params.output_dir}/multiqc", mode: 'copy', overwrite: true
//     executor "local"
//
//     input:
//     val(items) from bcl2fastq_output.mix(fastqc_fastqs)
//                                             .collect() // force it to wait for all steps to finish
//     file(output_dir) from Channel.fromPath("${params.output_dir}")
//
//     output:
//     file "multiqc_report.html" into multiqc_report_html
//     file "multiqc_data"
//
//     script:
//     """
//     echo \$PATH
//     echo \${PYTHONPATH:-"not set"}
//     echo \${PYTHONHOME:-"not set"}
//     module list
//
//     python --version
//     which python
//
//     which multiqc
//     multiqc --version
//     multiqc "${output_dir}"
//     """
// }

process demultiplexing_report {
    tag { "${template_dir}" }
    executor "local"
    publishDir "${params.output_dir}/demultiplexing-report", mode: 'copy', overwrite: true
    stageInMode "copy"

    input:
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

process convert_run_params{
    tag { "${run_params_xml_file}" }
    publishDir "${params.output_dir}/", mode: 'copy', overwrite: true
    executor "local"

    input:
    file(run_params_xml_file) from run_params_xml

    output:
    file("RunParameters.tsv") into run_params_tsv

    script:
    """
    RunParametersXML2tsv.py
    """
}

// // experimental email attachment collection method
// process collect_email_attachments {
//     tag { "${attachments}" }
//     executor "local"
//
//     input:
//     file(attachments: "*") from samplesheet_copy2.concat(demultiplex_stats_html, demultiplexing_report_html, run_params_tsv)
//
//     output:
//     val(attachments) into email_attachments
//
//     script:
//     """
//     """
// }
// email_attachments.collectFile(name: 'email_attachments.txt', storeDir: ".", newLine: true)
// email_attachments.subscribe{println "${it}"}


def attachments =  samplesheet_copy2.concat(demultiplex_stats_html, demultiplexing_report_html, run_params_tsv, run_RTAComplete_txt ).toList().getVal()
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
        Project directory : ${workflow.projectDir}
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
    if(params.pipeline_email) {
        sendMail {
            to "${params.email_to}"
            from "${params.email_from}"
            attach attachments
            subject "[${params.workflow_label}] ${status}: ${params.project}"
            body
            """
            ${msg}
            """
            .stripIndent()
        }
    }
}
