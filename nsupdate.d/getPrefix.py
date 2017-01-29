
import optparse
from netaddr.ip import IPNetwork, IPAddress



parser = optparse.OptionParser()

parser.add_option('-a', '--address',
                  action="store", dest="address",
                  help="ip v6 address", default="::1")
parser.add_option('-p', '--prefixlength',
                  action="store", dest="prefixlength",
                  help="prefix length", default="64")

options, args = parser.parse_args()

ipv6 = options.address + '/' + options.prefixlength
print IPNetwork(ipv6).network


