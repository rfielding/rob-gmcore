import logging
import subprocess

LOGGER = logging.getLogger(__name__)


# The way that we shell out to cue makes it dificult to write tests for
# These need to be "trusted" but we treat the json output as the interface
def cue_eval(tag_dict):
    eval_cmd = "cue eval -c ./inputs.cue ./global_intermediates.cue ./secrets.cue --out=json"
    LOGGER.info("Evaluating cue to create JSON")
    for i in tag_dict:
        eval_cmd = "%s -t %s=%s" % (eval_cmd, i, tag_dict[i])
    r = ""
    LOGGER.debug("Cue eval command: %s " % eval_cmd)
    try:
        r = getProcessOutput(eval_cmd)
    except subprocess.CalledProcessError as e:
        LOGGER.error("could not render json from cue eval string provided. \n%s" % e)
        raise e

    LOGGER.info("Done Evaluating cue to create JSON")
    return r


def getProcessOutput(cmd):
    process = subprocess.Popen(
        cmd,
        shell=True,
        stdout=subprocess.PIPE)
    process.wait()
    data, err = process.communicate()
    if process.returncode == 0:
        return data.decode('utf-8')
    else:
        LOGGER.error("Error:", err)
        raise Exception("Error running proccess [%s]" % (cmd, err))
