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

let tacServiceCBUUID = CBUUID(string: "0xFFE0") //This is the service UUID for the HM-10 device.
let tacCharacteristicsCBUUID = CBUUID(string: "FFE1") //This is the characteristic UUID of the HM-10.

let dataSet = [0, 0.0025, 0.0075, 0.025] //Sample data set to test making the chart view using Charts API.

extension ViewController: CBCentralManagerDelegate { //ViewController uses this delegate to handle CBCentralManager tasks.
  func centralManagerDidUpdateState(_ central: CBCentralManager) { //Function to tell the user when the phone is allowing BT connections.
    switch central.state { //Switch state to tell the user what state the BLE is in by printing to console.
    case .poweredOff:
      //print("central.state is .poweredOff") //These print statements are used merely for testing, should not print to console when app is fully built.
      print()
    case .poweredOn:
      //print("central.state is .poweredOn")
      centralManager.scanForPeripherals(withServices: [tacServiceCBUUID]) //Once the phone's BT is turned on, start scanning for peripherals with the
    default:                                                              //same name UUID as the HM-10.
      print()
    }
  }
  
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    print(peripheral)             //This function is used to scan for peripherals. When a peripheral is found with the same UUID as the HM-10, the scan
    tacPeripheral = peripheral    //is stopped and the iPhone connects to the device.
    tacPeripheral.delegate = self
    centralManager.stopScan()
    centralManager.connect(tacPeripheral)
  }
  
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    //print("Connected!")
    tacPeripheral.discoverServices([tacServiceCBUUID])
    //This function prints to the console that the device is connected, and discovers the peripheral's services using the UUID.
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

extension ViewController: CBPeripheralDelegate { //This delegate is used to handle the peripheral tasks once the connection has been established.
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) { //This function checks which services have been discovered for this peripheral.
    guard let services = peripheral.services else { return } //Making sure the peripheral has services.
    
    for service in services {
      print(service)
      peripheral.discoverCharacteristics(nil, for: service) //Discovers characteristics for each service.
    }
  }
  
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    guard let characteristics = service.characteristics else { return }
    
    for characteristic in characteristics { //Checking for specific characteristic properties for this peripheral.
      print(characteristic)
      if characteristic.properties.contains(.read) {
        //print("\(characteristic.uuid): properties contains .read")
        peripheral.readValue(for: characteristic)
      }
      if characteristic.properties.contains(.notify) {
        //print("\(characteristic.uuid): properties contains .notify")
        peripheral.setNotifyValue(true, for: characteristic)
      }

    }
  }
  
  //This function is used to run the onTACReceived function when the phone receives the correct characteristic from the peripheral.
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                  error: Error?) {
    switch characteristic.uuid {
      //When data is received with this UUID, the readWriteNotify function is called and the data is sent to the onTACReceived function.
      case tacCharacteristicsCBUUID: 
        let tac = readWriteNotify(from: characteristic)
        onTACReceived(tac)
      default:
        print("Unhandled Characteristic UUID: \(characteristic.uuid)")
    }
  }
  
  //This function returns the data being received from the Bluetooth transmitter.
  private func readWriteNotify(from characteristic: CBCharacteristic) -> Int
  {
    guard let characteristicData = characteristic.value else { return -1 } //Making sure there is actually a value being received.
    let stringInt = String.init(data: characteristicData, encoding: String.Encoding.utf8) //Converting data packet from 8 byte to String.
    let tacInt = Int.init(stringInt ?? "") ?? 0 //Converting String to Int
    return tacInt //Return Int
  }
}
