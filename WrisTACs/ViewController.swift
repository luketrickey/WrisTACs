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


class ViewController: UIViewController {
    @IBOutlet weak var tacLabel: UILabel!
    @IBOutlet weak var chartView: LineChartView!
    
    var centralManager: CBCentralManager!
    var tacPeripheral: CBPeripheral!

    override func viewDidLoad() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    
        super.viewDidLoad()
        showText()
        customizeChart(values: dataSet.map{ Double($0) })
    }
    
    func customizeChart(values: [Double]) {
        var dataEntries: [ChartDataEntry] = []
        for i in 0..<values.count {
            let dataEntry = ChartDataEntry(x: Double(i), y: values[i])
            dataEntries.append(dataEntry)
        }
        
        let lineChartDataSet = LineChartDataSet(entries: dataEntries, label: nil)
        let lineChartData = LineChartData(dataSet: lineChartDataSet)
        chartView.data = lineChartData
    }
    
    func onTACReceived(_ tac: Int) {
        var tacDouble = Double(tac)
        tacDouble *= (0.0225/520)
        var tacString = String(tacDouble)
        if tacString.count >= 6 {
            let range = tacString.index(tacString.startIndex, offsetBy: 6)..<tacString.endIndex
            tacString.removeSubrange(range)
        }
        tacLabel.text = tacString
        print("TAC: \(tacDouble)")
    }
    
    func showText() {
        tacLabel.text = "--"
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
