//
//  ViewController.swift
//  WrisTACs
//
//  Created by Luke Trickey on 6/14/20.
//  Copyright © 2020 WrisTACs. All rights reserved.
//

import UIKit
import CoreBluetooth
import Charts

let tacServiceCBUUID = CBUUID(string: "0xFFE0")
let tacCharacteristicsCBUUID = CBUUID(string: "FFE1")

let dataSet = [0, 0.0025, 0.0075, 0.025]

extension ViewController: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .poweredOff:
      print("central.state is .poweredOff")
    case .poweredOn:
      print("central.state is .poweredOn")
      centralManager.scanForPeripherals(withServices: [tacServiceCBUUID])
    default:
      print()
    }
  }
  
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    print(peripheral)
    tacPeripheral = peripheral
    tacPeripheral.delegate = self
    centralManager.stopScan()
    centralManager.connect(tacPeripheral)
  }
  
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    print("Connected!")
    tacPeripheral.discoverServices([tacServiceCBUUID])
  }
}


class ViewController: UIViewController { //ViewController for the "Live Data" screen.
    @IBOutlet weak var tacLabel: UILabel! //Controls the UILabel that displays the users TAC in real time.
    @IBOutlet weak var chartView: LineChartView! //Controls the line chart view.
    
    var centralManager: CBCentralManager!
    var tacPeripheral: CBPeripheral!

    override func viewDidLoad() {
        centralManager = CBCentralManager(delegate: self, queue: nil) //Object used to discover and connect to peripheral devices; in this case, the HM-10 adapter connected to the Arduino.
    
        super.viewDidLoad()
        showText() //Calls showText function for this ViewController.
        displayChart(values: dataSet.map{ Double($0) }) //Calls displayChart function using dataSet values as data entries.
    }
    
    func displayChart(values: [Double]) { //This function displays the chart to the user, allowing them to see the progression of their TAC of the collection period.
        var dataEntries: [ChartDataEntry] = [] //Initializing dataEntries list to be populated in the following for loop.
        for i in 0..<values.count { //for loop iterates through each value in the data set.
            let dataEntry = ChartDataEntry(x: Double(i), y: values[i]) //Converting values from data set into chart data.
            dataEntries.append(dataEntry) //Chart data is then used to populate dataEntries list.
        }
        
        let lineChartDataSet = LineChartDataSet(entries: dataEntries, label: nil) //The next two lines are creating the data set out of entries in dataEntries list.
        let lineChartData = LineChartData(dataSet: lineChartDataSet)
        chartView.data = lineChartData //Finally, chartView UIView is set equal to our chart data.
    }
    
    func onTACReceived(_ tac: Int) { //This function deals with converting and displaying the data being recieved from the HM-10 module.
        var tacDouble = Double(tac) //Converting the data from HM-10 into Double.
        tacDouble *= (0.0225/520) //Converting that Double to TAC level using our TAC algorithm developed in earlier testing.
        var tacString = String(tacDouble) //Converting TAC level into a String that can be displayed to the user.
        if tacString.count >= 6 { //This if statement mearly cuts off the end of the Double if it goes past 5 digits (0.xxx...) so that it can be fully displayed to the user.
            let range = tacString.index(tacString.startIndex, offsetBy: 6)..<tacString.endIndex //Note that only the String is truncated, the Double remains as the full value.
            tacString.removeSubrange(range) //Removing the end of the tacString.
        }
        tacLabel.text = tacString //Displaying TAC string to the user with the tacLabel variable that is connected to a UILabel in the Storyboard.
        //print("TAC: \(tacDouble)") //Line was used to output the TAC in the console for testing purposes, but does not need to be included in the final application.
    }
    
    func showText() { //Function to be run when ViewController is initialized.
        tacLabel.text = "--" //Dummy text to tell the user that the actual TAC reading will be displayed momentarily.
    }
}

extension ViewController: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard let services = peripheral.services else { return }
    
    for service in services {
      print(service)
      peripheral.discoverCharacteristics(nil, for: service)
    }
  }
  
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    guard let characteristics = service.characteristics else { return }
    
    for characteristic in characteristics {
      print(characteristic)
      if characteristic.properties.contains(.read) {
        print("\(characteristic.uuid): properties contains .read")
        peripheral.readValue(for: characteristic)
      }
      if characteristic.properties.contains(.notify) {
        print("\(characteristic.uuid): properties contains .notify")
        peripheral.setNotifyValue(true, for: characteristic)
      }

    }
  }
  
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                  error: Error?) {
    switch characteristic.uuid {
      case tacCharacteristicsCBUUID:
        let tac = readWriteNotify(from: characteristic)
        onTACReceived(tac)
      default:
        print("Unhandled Characteristic UUID: \(characteristic.uuid)")
    }
  }
  
  private func readWriteNotify(from characteristic: CBCharacteristic) -> Int
  {
    guard let characteristicData = characteristic.value else { return -1 }
    let stringInt = String.init(data: characteristicData, encoding: String.Encoding.utf8)
    let tacInt = Int.init(stringInt ?? "") ?? 0
    return tacInt    
  }
}
