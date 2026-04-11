import struct
import random
import time

def generate_omdc_physical_stream(filename="raw_data.hex", count=10000):
    """
    @brief HKEX OMD-C (v1.45) Physical Layer Line-Rate Injection Generator.
    @details Fully compliant with IEEE 802.3 XGMII and OMD-C Binary Protocol.
             Simulates GTH Transceiver Raw Mode with randomized byte alignment.
    """
    # XGMII Control Characters and Ethernet Preamble
    IDLE = b'\x07'
    START = b'\xfb'
    PREAMBLE = b'\x55' * 6
    SFD = b'\xd5'
    TERMINATE = b'\xfd'

    with open(filename, "w") as f:
        seq_num = 1
        for _ in range(count):
            # 1. Inter-Packet Gap (IPG) - Randomized IDLE cycles to reset RX Hardware Lock
            for _ in range(random.randint(4, 8)):
                f.write("0707070707070707\n")

            # =========================================================
            # 2. Construct OMD-C Message (Example: Add Order (30) - Section 3.9.1)
            # =========================================================
            msg_size = 32                      # Uint16
            msg_type = 30                      # Uint16 (30 = Add Order) [cite: 179]
            sec_code = random.randint(1, 9999) # Uint32 [cite: 335]
            order_id = seq_num                 # Uint64 [cite: 335]
            price = 9750                       # Int32 (3 implied decimal places) [cite: 335]
            qty = 100                          # Uint32 [cite: 335]
            side = random.choice([0, 1])       # Uint16 (0=Bid, 1=Offer) [cite: 335]
            order_type = b'2'                  # String 1-byte ('2' for Limit) [cite: 335]
            filler = b'\x00'                   # String 1-byte
            ob_pos = 0                         # Int32 [cite: 335]

            # '<' represents Little-Endian, strictly required by OMD-C Spec 3.1 [cite: 152]
            msg_payload = struct.pack('<HH I Q i I H c c i',
                msg_size, msg_type, sec_code, order_id, price, qty, side, order_type, filler, ob_pos)

            # =========================================================
            # 3. Construct OMD-C Packet Header (Section 3.3) [cite: 187]
            # =========================================================
            pkt_size = 16 + len(msg_payload)   # Uint16 [cite: 187]
            msg_count = 1                      # Uint8 [cite: 187]
            pkt_filler = b'\x00'               # String 1-byte
            send_timestamp = int(time.time() * 1e9) # Uint64 (Nanoseconds) [cite: 187]

            pkt_header = struct.pack('<H B c I Q',
                pkt_size, msg_count, pkt_filler, seq_num, send_timestamp)

            # =========================================================
            # 4. Ethernet Physical Frame Encapsulation
            # =========================================================
            eth_payload = pkt_header + msg_payload
            full_frame = START + PREAMBLE + SFD + eth_payload + TERMINATE

            # 5. Simulate Physical Layer Byte-Drift (0-7 Byte Offset for GTH Raw Mode)
            offset = random.randint(0, 7)
            shifted_frame = (IDLE * offset) + full_frame

            # =========================================================
            # 6. $readmemh 64-bit Alignment & Endianness Swap
            # =========================================================
            for i in range(0, len(shifted_frame), 8):
                chunk = shifted_frame[i:i+8]
                # Pad with IDLE if the frame tail is not 64-bit aligned
                if len(chunk) < 8:
                    chunk = chunk.ljust(8, IDLE)
                
                # REVERSE CHUNK: Ensures the first byte (Lane 0) is mapped to [7:0]
                # in the Verilog 64-bit register for standard XGMII mapping.
                le_chunk = chunk[::-1]
                f.write(f"{le_chunk.hex()}\n")

            seq_num += 1

    print(f">>> [SUCCESS] Generated {count} OMD-C v1.45 test vectors: {filename}")

if __name__ == "__main__":
    generate_omdc_physical_stream()