U0 HandleNetFifoEntry(CNetFifoEntry* e) {
  CEthFrame l2_frame;

  if (EthernetFrameParse(&l2_frame, e->frame, e->length) < 0)
    return;

  //"NetFifoEntry %04X\n", l2_frame.ethertype;

  CL3Protocol* l3 = l3_protocols;

  while (l3) {
    if (l3->ethertype == l2_frame.ethertype) {
      l3->handler(&l2_frame);
      break;
    }
    l3 = l3->next;
  }
}

U0 VirtioNetHandlerTask()
{
  I64 idx_used, idx_rec;
  I64 i,j;
  EVirtioUsedItem *item;
  U8 *buffer;
  I64 length;
  while (1)
  {
    idx_rec = virtio_net.rq_index;
    idx_used = virtio_net.rq->used.index;

    if (idx_used < idx_rec)
    {
      idx_used += 0x10000;
    }

    if (idx_rec != idx_used && idx_used)
    {

      j=0;
      for (i=idx_rec; i<idx_used; i++)
      {
        item = virtio_net.rq->used.ring;
        buffer = virtio_net.rq->buffers[item[i%256].index+1];
        length = item[i%256].length;
        NetFifoPushCopy(buffer, length-10);
        j++;
        virtio_net.rx_packets++;
        virtio_net.rx_bytes += length-10;
      }
      virtio_net.rq_index = idx_used%0x10000;
      virtio_net.rq->available.index += j;
      OutU16(virtio_net.port + VIRTIO_PCI_QUEUE_NOTIFY, 0);  
    }
    CNetFifoEntry* e = NetFifoPull;
    if (e) {
      HandleNetFifoEntry(e);
    }
    Yield;
  }
}

EthernetInit;
Spawn(&VirtioNetHandlerTask,,,mp_cnt-1);