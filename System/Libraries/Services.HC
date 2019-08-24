// Generic Library for Erythros Services

#define EOS_SVC_STOPPED        0
#define EOS_SVC_RUNNING        1

class EService {
    EService *prev;
    EService *next;
    Bool enabled;
    U8 *name;
    I64 status;
    I64 flags;
    U64 func;
    U64 cb;
    CTask *task;
};

EService *eos_services = CAlloc(sizeof(EService));

U0 EOSRegisterService(U8 *name, U64 func, I64 flags=NULL, U64 cb=NULL) {
    EService *prev = eos_services;
    while (prev->next)
    {
        prev = prev->next;
    }
    EService *new = CAlloc(sizeof(EService));
    new->name = StrNew(name);
    new->func = func;
    new->cb = cb;
    new->flags = flags;
    prev->next=new;
    new->prev=prev;
}

I64 EOSDisableService(U8 *name)
{
    EService *svc = eos_services->next;
    while (svc)
    {
        if (!StrCmp(svc->name, name))
        {
            if (svc->task)
            {
                while (TaskValidate(svc->task))
                {
                    Kill(svc->task);
                    Sleep(1);
                }
                svc->task = NULL;
                svc->enabled = FALSE;
                return 0;
            }
        }
        svc = svc->next;
    }
    return -1;
}

I64 EOSEnableService(U8 *name)
{
    EService *svc = eos_services->next;
    while (svc)
    {
        if (!StrCmp(svc->name, name))
        {
            svc->enabled = TRUE;
            return 0;
        }
        svc = svc->next;
    }
    return -1;
}

I64 EOSStartService(U8 *name)
{
    EService *svc = eos_services->next;
    while (svc)
    {
        if (!StrCmp(svc->name, name))
        {
            if (!svc->task && svc->status!=EOS_SVC_RUNNING)
            {
                svc->task=Spawn(svc->func,,,mp_cnt-2);
                svc->task->task_end_cb=svc->cb;
                svc->status = EOS_SVC_RUNNING;
                return 0;
            }
        }
        svc = svc->next;
    }
    return -1;
}

I64 EOSStopService(U8 *name)
{
    EService *svc = eos_services->next;
    while (svc)
    {
        if (!StrCmp(svc->name, name))
        {
            if (svc->task && svc->status==EOS_SVC_RUNNING)
            {
                while (TaskValidate(svc->task))
                {
                    Kill(svc->task);
                    Sleep(1);
                }
                svc->status = EOS_SVC_STOPPED;
                return 0;
            }
        }
        svc = svc->next;
    }
    return -1;
}

I64 EOSQueryServiceStatus(U8 *name)
{
    EService *svc = eos_services->next;
    while (svc)
    {
        if (!StrCmp(svc->name, name))
        {
            return svc->status;
        }
        svc = svc->next;
    }
    return -1;
}

I64 EOSQueryServiceEnabled(U8 *name)
{
    EService *svc = eos_services->next;
    while (svc)
    {
        if (!StrCmp(svc->name, name))
        {
            return svc->enabled;
        }
        svc = svc->next;
    }
    return -1;
}