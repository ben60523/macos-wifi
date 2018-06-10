import Foundation
import CoreWLAN

// CLI helpers

private func basename(_ pathOption: String?) -> String? {
  if let path = pathOption {
    return URL(fileURLWithPath: path).lastPathComponent
  }
  return nil
}

private func printUsage() {
  let process = basename(CommandLine.arguments.first) ?? "executable"
  printErr("Usage: \(process) [-h|--help] -action scan|associate [-bssid bssid]")
}

// CLI actions

func scan(_ interface: CWInterface) throws {
  printErr("Available interfaces:")
  for interfaceName in CWWiFiClient.interfaceNames() ?? [] {
    printOut("  \(interfaceName)")
  }
  printErr("Using interface: \(interface)")
  printErr("Current interface:")
  printOut(formatKVTable(interfaceDictionary(interface)))

  let networks = try interface.scanForNetworks(withSSID: nil)
  printErr("Available networks:")
  let networkDictionaries = networks.map(networkDictionary)
  let keys = [
    "SSID", "BSSID",
    "ChannelNumber", "ChannelBand", "ChannelWidth",
    "RSSI",
    "Noise",
    // "InformationElement",
    // "BeaconInterval",
    // "IBSS",
    "Country",
  ]
  printOut(formatTable(Array(networkDictionaries), keys: keys))
}

func associate(_ interface: CWInterface, bssid: String) throws {
  let networks = try interface.scanForNetworks(withSSID: nil)
  printErr("Associating with bssid:", bssid)
  if let targetNetwork = networks.first(where: {$0.bssid == bssid}) {
    let password = args.dropFirst().first
    try interface.associate(to: targetNetwork, password: password)
  } else {
    printErr("No network matching bssid found!")
  }
}

// CLI entry point

func main(_ args: [String]) {
  // handle boolean arguments separately since UserDefaults only processes '-key value' pairs
  if (args.contains { arg in arg == "-h" || arg == "-help" || arg == "--help" }) {
    printUsage()
    exit(0)
  }
  // use UserDefaults to parse other command line arguments
  let defaults = UserDefaults.standard

  let action = defaults.string(forKey: "action") ?? "scan"

  let client = CWWiFiClient.shared()
  let interface = client.interface()!

  switch action {
  case "scan":
    try! scan(interface)
  case "associate":
    if let bssid = defaults.string(forKey: "bssid") {
      try! associate(interface, bssid: bssid)
    } else {
      printErr("The 'associate' action requires supplying a -bssid value")
      printUsage()
      exit(1)
    }
  default:
    printErr("Unrecognized action: \(action)")
    printUsage()
    exit(1)
  }
}

// CommandLine.arguments[0] is the path of the executed file, which we drop
let args = Array(CommandLine.arguments.dropFirst())
main(args)
