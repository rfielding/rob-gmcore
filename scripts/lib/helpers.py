import logging

LOGGER = logging.getLogger(__name__)


# Read input file
def read_file(src_file):
    data = ""
    try:
        LOGGER.info("Reading file %s" % src_file)
        with open(src_file) as f:
            data = f.read()
    except Exception as e:
        LOGGER.error("Could not read in [%s]" % src_file)
        raise e
    return data


# Write output file
def write_file(data, dest_file):
    try:
        LOGGER.debug("Writing to file [%s]" % dest_file)
        with open(dest_file, "w") as f:
            f.write(data)
    except Exception as e:
        LOGGER.error("Could not write to file [%s]" % dest_file)
        raise e
